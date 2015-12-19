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
END;
$$ language plpgsql;


