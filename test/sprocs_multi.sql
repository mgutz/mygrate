/**
 * Fans wants to join a fan game.
 */
create function f_fangames_join(
    _bounty_id bigint,
    _user_id bigint,
    _amount decimal(12, 2),
    _gamer_tag text = '',
    _comment text = '',
    _team_id bigint = null,
    OUT _account_transaction_id bigint
) as $$
DECLARE
BEGIN
    _account_transaction_id = 0;

    IF _amount > 0 AND EXISTS(SELECT * FROM bounties WHERE created_by = _user_id AND id = _bounty_id) THEN
        RAISE EXCEPTION 'Creator is not allowed to donate to his own game.';
    END IF;

    IF _amount < 0.01 THEN
        _amount = 0.0;
    END IF;

    IF _amount > 0.01 OR _comment != '' THEN
        INSERT INTO account_transactions (account_id, amount, created_by, bounty_id, action, comment)
        VALUES (_user_id, _amount, _user_id, _bounty_id, 'bounty:pool', _comment)
        RETURNING id into _account_transaction_id;

        -- add to pending balance
        IF _amount > 0.01 THEN
            UPDATE accounts
            SET pending = pending + _amount, balance = balance - _amount
            WHERE id = _user_id;
        END IF;
    END IF;

    -- a user can only be in the pool once
    IF EXISTS(SELECT 1 FROM bounty_pool WHERE bounty_id = _bounty_id AND user_id = _user_id) THEN
        RAISE NOTICE 'user % is already in the pool', _user_id;
        RETURN;
    END IF;

    INSERT INTO bounty_pool(bounty_id, team_id, user_id, account_transaction_id, account_name)
    VALUES (_bounty_id, _team_id, _user_id, _account_transaction_id, _gamer_tag);
END;
$$ language plpgsql;

GO

/**
 * Set the selected players for each team.
 *
 * It is assumed that the team was created before calling this
 * function.
 */
create function f_fangames_set_teams(
    _bounty_id bigint,
    _team1_id bigint,
    _team1_users json,
    _team2_id bigint,
    _team2_users json,
    _streamer_id bigint
) RETURNS void as $$
DECLARE
    _count bigint;
    _length int;
BEGIN
    -- ensure user is the streamer (created_by)
    SELECT count(id) INTO _count
    FROM bounties
    WHERE id = _bounty_id
    AND created_by = _streamer_id;

    IF _count < 1 THEN
        RAISE EXCEPTION 'Only the streamer can set the team in a fan game';
    END IF;


    -- create team1 (if present)
    SELECT json_array_length(_team1_users) INTO _length;
    IF _length > 0 THEN
        -- user must be in the bounty pool
        SELECT count(id) INTO _count
        FROM bounty_pool
        WHERE bounty_id = _bounty_id
            AND user_id IN (
                SELECT value::text::bigint
                FROM json_array_elements(_team1_users)
            );

        IF _length != _count THEN
            RAISE EXCEPTION 'Mismatch between users in the pool and the team being set count=% length=%', _count, _length;
        END IF;

        -- if a team does not exst, create an empty team
        IF coalesce(_team1_id, 0) < 1 THEN
            insert into bounty_teams(bounty_id)
            values (_bounty_id)
            returning id into _team1_id;
        END IF;

        -- add users to teams
        INSERT INTO team_users(account_name, bounty_team_id, user_id, status)
        SELECT bp.account_name, _team1_id, bp.user_id, 'ready'
        FROM bounty_pool bp
        WHERE bp.bounty_id = _bounty_id
            AND bp.user_id in (
                SELECT value::text::bigint
                FROM json_array_elements(_team1_users)
            );
    END IF;

    -- create team2 (if present)
    SELECT json_array_length(_team2_users) INTO _length;
    IF _length > 0 THEN
        -- user must be in the bounty pool
        SELECT count(id) INTO _count
        FROM bounty_pool
        WHERE bounty_id = _bounty_id
            AND user_id IN (
                SELECT value::text::bigint
                FROM json_array_elements(_team2_users)
            );

        IF _length != _count THEN
            RAISE EXCEPTION 'Mismatch between users in the pool and the team being set count=% length=%', _count, _length;
        END IF;

        -- if a team does not exst, create an empty team
        IF coalesce(_team2_id, 0) < 1 THEN
            insert into bounty_teams(bounty_id)
            values (_bounty_id)
            returning id into _team2_id;
        END IF;

        -- add users to teams
        INSERT INTO team_users(account_name, bounty_team_id, user_id, status)
        SELECT bp.account_name, _team2_id, bp.user_id, 'ready'
        FROM bounty_pool bp
        WHERE bp.bounty_id = _bounty_id
            AND bp.user_id in (
                SELECT value::text::bigint
                FROM json_array_elements(_team2_users)
            );
    END IF;
END;
$$ language plpgsql;

GO

/**
 * Replaces a user in a bounty.
 */
create function f_fangames_replace_user(
    _session_id bigint,
    _bounty_id bigint,
    _user_id bigint,
    _replace_user_id bigint
) RETURNS void as $$
DECLARE
BEGIN
    UPDATE team_users
    SET user_id = _user_id
    WHERE user_id = _replace_user_id
        AND bounty_team_id = (
            SELECT bt.id
            FROM bounty_teams bt
                JOIN bounties b ON (b.id = bt.bounty_id)
            WHERE b.id = _bounty_id
                AND b.created_by = _session_id
        );
END;
$$ language plpgsql;

GO

/**
 * Finalizes refunds all non-selected donations.
 */
CREATE FUNCTION f_fangames_finalize(
    _bounty_id bigint,
    _user_id bigint
) RETURNS void as $$
DECLARE
    _amount decimal(12, 2);
BEGIN
    CREATE TEMP TABLE _players (
        id bigint
    ) ON COMMIT DROP;

    -- players who were selected INCLUDING streamer who might
    -- join one of the teams
    INSERT INTO _players(id)
    SELECT tu.user_id
    FROM bounties b
        JOIN bounty_teams bt ON (bt.bounty_id = b.id)
        JOIN team_users tu ON (tu.bounty_team_id = bt.id)
    WHERE b.id = _bounty_id
        AND b.created_by = _user_id;

    -- return all bounty:pool non-selected players, 40 is the predefined admin user
    INSERT INTO account_transactions (action, account_id, amount, comment, created_by)
    SELECT 'refund', atx.account_id, atx.amount, 'not selected in fan-game',  40
    FROM account_transactions atx
    WHERE atx.bounty_id = _bounty_id
        AND atx.account_id NOT IN (SELECT id FROM _players)
        AND atx.action = 'bounty:pool';

    -- reflect update in the balance and pending amount of non-selected users
    UPDATE accounts AS acc
    SET balance = balance + atx.amount, pending = pending - atx.amount
    FROM account_transactions atx
    WHERE atx.account_id = acc.id
        AND atx.bounty_id = _bounty_id
        AND atx.account_id NOT IN (SELECT id FROM _players)
        AND atx.action = 'bounty:pool';

    SELECT sum(coalesce(atx.amount, 0)) INTO _amount
    FROM account_transactions atx
    WHERE atx.bounty_id = _bounty_id
        AND atx.account_id IN (SELECT id FROM _players)
        AND atx.action = 'bounty:pool';

    -- update the balance of the bounty
    UPDATE bounties
    SET status = 'ready',
        balance = (
        SELECT sum(amount)
        FROM account_transactions atx
        WHERE atx.bounty_id = _bounty_id
            AND atx.account_id IN (SELECT id FROM _players)
            AND atx.action = 'bounty:pool'
    )
    WHERE id = _bounty_id;
END;
$$ language plpgsql;


