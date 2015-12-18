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

