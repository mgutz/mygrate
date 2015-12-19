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

