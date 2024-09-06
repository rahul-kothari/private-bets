use dep::aztec::{
    hash::compute_secret_hash, prelude::AztecAddress,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
    protocol_types::storage::map::derive_storage_slot_in_map,
    note::{note_getter::{MAX_NOTES_PER_PAGE, view_notes}, note_viewer_options::NoteViewerOptions},
    oracle::{execution::{get_block_number, get_contract_address}, unsafe_rand::unsafe_rand, storage::storage_read}
};
use dep::authwit::cheatcodes as authwit_cheatcodes;

use dep::token::{
    Token,
    types::{token_note::TokenNote, transparent_note::TransparentNote}
};

use crate::Bet;

global COINS: [AztecAddress; 10] = [ AztecAddress { inner: 1 }, AztecAddress { inner: 2 }, AztecAddress { inner: 3 }, AztecAddress { inner: 4 }, AztecAddress { inner: 5 }, AztecAddress { inner: 6 }, AztecAddress { inner: 7 }, AztecAddress { inner: 8 }, AztecAddress { inner: 9 }, AztecAddress { inner: 10 }];
global EXPIRY_BLOCK_NUM_DIFFERENTIAL: u32 = 1000;
global INITIAL_MINT_AMOUNT: Field = 10000;

#[test]
unconstrained fn basic_bet() {
    let (env, token_contract_address, token_admin, bet_contract_address, users) = setup_and_mint_privately(); 
    let amount_to_bet = 100;
    let coin_to_bet = COINS[2];
    let user = users[0];

    create_bet(env, token_contract_address, bet_contract_address, user, amount_to_bet, coin_to_bet);
    check_bets_balance(bet_contract_address, coin_to_bet, amount_to_bet);
    
    // check amount was transferred from user to bet contract
    check_private_token_balance(token_contract_address, user, INITIAL_MINT_AMOUNT - amount_to_bet);
    check_public_token_balance(token_contract_address, bet_contract_address, 100);

    // check winner and loser. Since no bets on any coin - no amount to rug
    check_winner_and_loser(env, bet_contract_address, coin_to_bet, COINS[0], 0);

    // not working
    // let bet_call_interface = Bet::at(bet_contract_address).claim_coins(amount_to_bet, coin_to_bet, user);
    // env.call_private_void(bet_call_interface);
    // there was only 100 bet. And all of that belongs to user!
    // check_public_token_balance(token_contract_address, bet_contract_address, 0);
    // check_public_token_balance(token_contract_address, user, INITIAL_MINT_AMOUNT);

}

// test multiple bets of various coins to test rugged amount
#[test]
unconstrained fn mul_bets() {
    let (env, token_contract_address, token_admin, bet_contract_address, users) = setup_and_mint_privately(); 

    // we only created 2 users but simulate them as multiple:
    // user0 bets 100 on coin 0. user1 bets 50 on coin 2. 
    // user0 bets 70 on coin 1. user1 bets 80 on coin 3.
    // user0 bets 100 on coin 0. user1 bets 90 on coin4.
    create_bet(env, token_contract_address, bet_contract_address, users[0], 100, COINS[0]);
    create_bet(env, token_contract_address, bet_contract_address, users[0], 70, COINS[1]);
    create_bet(env, token_contract_address, bet_contract_address, users[0], 110, COINS[0]);
    create_bet(env, token_contract_address, bet_contract_address, users[1], 50, COINS[2]);
    create_bet(env, token_contract_address, bet_contract_address, users[1], 80, COINS[3]);
    create_bet(env, token_contract_address, bet_contract_address, users[1], 90, COINS[4]);

    let expected_user0_bal = INITIAL_MINT_AMOUNT - 280; // 100 + 70 + 110
    let expected_user1_bal = INITIAL_MINT_AMOUNT - 220; // 50 + 80 + 90

    check_private_token_balance(token_contract_address, users[0], expected_user0_bal); 
    check_private_token_balance(token_contract_address, users[1], expected_user1_bal);
    check_public_token_balance(token_contract_address, bet_contract_address, 500); // bet contract got 280+220 worth of bets

    check_bets_balance(bet_contract_address, COINS[0], 210); // 100 + 110
    check_bets_balance(bet_contract_address, COINS[1], 70);
    check_bets_balance(bet_contract_address, COINS[2], 50);
    check_bets_balance(bet_contract_address, COINS[3], 80);
    check_bets_balance(bet_contract_address, COINS[4], 90);

    // 70 + 50 + 80 + 90 = 290/2 to be distributed equally amongst winners (coins[0]) and losers (coins[5])
    let mut block_number = get_block_number();
    let mut expired_block: U128 = storage_read(bet_contract_address,Bet::storage().expiry_block_number.slot, block_number );   
    std::println(f"block_number: {block_number}"); 
    std::println(f"expired_block: {expired_block}");
    check_winner_and_loser(env, bet_contract_address, COINS[0], COINS[5], 145);
    std::println(f"expired_block: {expired_block}");
    block_number = get_block_number();

    // env.imperesonate(user);
    // user0 won with their 210 bet on coin0. They should get 210 * 145 / 210 = 145 + 210 back  
    // not working?????
    // std::println(f"block_number: {block_number}"); 
    // std::println(f"expired_block: {expired_block}");
    // env.call_private_void(Bet::at(bet_contract_address).claim_coins(U128::from_field(210), COINS[0], users[0]));
    // check_public_token_balance(token_contract_address, users[0], expected_user0_bal + 210 + 145);
    // check_public_token_balance(token_contract_address, bet_contract_address, 500 - 210 - 145);
}
// test all coins have something
// test psot expiry
// test incorrect coin
// test claiming a mid coin!



pub fn setup()  -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress) {
    // Setup env
    let mut env = TestEnvironment::new();

    // deploy token
    let token_admin = env.create_account(); 
    let token_initializer = Token::interface().constructor(token_admin,"TestToken0000000000000000000000","TT00000000000000000000000000000",18);
    let token_contract = env.deploy("../../../nargo/github.com/AztecProtocol/aztec-packagesaztec-packages-v0.52.0/noir-projects/noir-contracts@token_contract", "Token").with_public_initializer(token_initializer);
    let token_contract_address = token_contract.to_address();

    // deploy Bet
    let expiry_block_number = env.block_number() + EXPIRY_BLOCK_NUM_DIFFERENTIAL;
    let bet_initializer = Bet::interface().constructor(COINS, expiry_block_number, token_contract_address);
    let bet_contract = env.deploy_self("Bet").with_public_initializer(bet_initializer);
    let bet_contract_address = bet_contract.to_address();

    let expiry_slot = Bet::storage().expiry_block_number.slot;
    let actual_expiry: u32 = storage_read(bet_contract_address, expiry_slot, env.block_number());
    assert(actual_expiry == expiry_block_number, "incorrect expiry");

    let bet_coin_accepted_slot = Bet::storage().bet_coin_accepted.slot;
    let actual_bet_coin_accepted: AztecAddress = storage_read(bet_contract_address, bet_coin_accepted_slot, env.block_number());
    assert(actual_bet_coin_accepted == token_contract_address, "incorrect bet coin");
    env.advance_block_by(1);

    // std::println(f"token_admin: {token_admin}");
    // std::println(f"token_contract_address: {token_contract_address}");
    // std::println(f"bet_contract_address: {bet_contract_address}");

    // return vals
    (&mut env, token_contract_address, token_admin, bet_contract_address)
}

pub fn setup_and_mint_privately() -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress, [AztecAddress; 2]) {
    // Setup
    let (env, token_contract_address, token_admin, bet_contract_address) = setup();
    let user1 = env.create_account_contract(1);
    let user2 = env.create_account_contract(2);
    let users = [ user1, user2];

    env.impersonate(token_admin);

    // Mint some tokens
    for i in 0 .. 2 {
        let secret = unsafe_rand();
        let secret_hash = compute_secret_hash(secret);
        let mint_private_call_interface = Token::at(token_contract_address).mint_private(INITIAL_MINT_AMOUNT, secret_hash);

        env.call_public(mint_private_call_interface);

        // Time travel so we can read keys from the registry
        env.advance_block_by(6);

        // Store a note in the cache so we can redeem it
        env.store_note_in_cache(
            &mut TransparentNote::new(INITIAL_MINT_AMOUNT, secret_hash),
            Token::storage().pending_shields.slot,
            token_contract_address
        );

        // Redeem our shielded tokens to a new account:
        let redeem_shield_call_interface = Token::at(token_contract_address).redeem_shield(users[i], INITIAL_MINT_AMOUNT, secret);
        env.call_private_void(redeem_shield_call_interface);

        check_private_token_balance(token_contract_address, users[i], INITIAL_MINT_AMOUNT)
    }
    // return vals
    (env, token_contract_address, token_admin, bet_contract_address, users)
}

pub fn check_private_token_balance(token_contract_address: AztecAddress, address: AztecAddress, address_amount: Field) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(token_contract_address);
    // Direct call to unconstrained
    let address_private_balance = Token::balance_of_private(address);
    std::println(f"address_private_balance {address_private_balance}");
    assert(address_private_balance == address_amount, "Private balance is not correct");
    cheatcodes::set_contract_address(current_contract_address);
}

pub fn check_public_token_balance(token_contract_address: AztecAddress, address: AztecAddress, address_amount: Field) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(token_contract_address);
    let block_number = get_block_number();

    let balances_slot = Token::storage().public_balances.slot;
    let address_slot = derive_storage_slot_in_map(balances_slot, address);
    let public_balance: U128 = storage_read(token_contract_address, address_slot, block_number);
    std::println(f"public_balance {public_balance}");
    assert(public_balance.to_field() == address_amount, "Public balance is not correct");
    cheatcodes::set_contract_address(current_contract_address);
}

pub fn create_bet(
    env: &mut TestEnvironment, 
    token_contract_address: AztecAddress, 
    bet_contract_address: AztecAddress, 
    user: AztecAddress, 
    amount_to_bet: Field, 
    coin_to_bet: AztecAddress) {
    
    // user needs to set up authwit to let bet contract unshield!! 
    env.impersonate(user);
    let unshield_call_interface = Token::at(token_contract_address).unshield(user, bet_contract_address, amount_to_bet, 0);
    authwit_cheatcodes::add_private_authwit_from_call_interface(user, bet_contract_address, unshield_call_interface);

    // // bet!
    let bet_call_interface = Bet::at(bet_contract_address).bet(amount_to_bet, coin_to_bet);
    env.call_private_void(bet_call_interface);
    cheatcodes::set_contract_address(get_contract_address());
}

pub fn check_bets_balance(bet_contract_address: AztecAddress, coin: AztecAddress, expected_amount: Field) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(bet_contract_address);
    let block_number = get_block_number();

    let bets_slot = Bet::storage().bets.slot;
    let address_slot = derive_storage_slot_in_map(bets_slot, coin);
    let bets_balance_for_coin: U128 = storage_read(bet_contract_address, address_slot, block_number);
    std::println(f"bets_balance_for_coin: {bets_balance_for_coin}");
    assert(bets_balance_for_coin.to_field() == expected_amount, "bets balance is not correct");
    cheatcodes::set_contract_address(current_contract_address);
}

pub fn check_winner_and_loser(env: &mut TestEnvironment, bet_contract_address: AztecAddress, expected_winner: AztecAddress, expected_loser: AztecAddress, expected_distributed_amount: Field) {
    env.advance_block_by(EXPIRY_BLOCK_NUM_DIFFERENTIAL + 10); // expired
    let winner_and_loser_call_interface = Bet::at(bet_contract_address).announce_winner_and_loser(COINS);
    env.call_public(winner_and_loser_call_interface);
    let block_number = get_block_number();
    let winner_coin: AztecAddress = storage_read(bet_contract_address, Bet::storage().winner_coin.slot, block_number);
    let loser_coin: AztecAddress = storage_read(bet_contract_address, Bet::storage().loser_coin.slot, block_number);
    // std::println(f"winner_coin: {winner_coin}");
    // std::println(f"loser_coin: {loser_coin}");
    assert(expected_winner == winner_coin, "incorrect expected winner");
    assert(expected_loser == loser_coin, "incorrect expected loser");

    let distributed_amount_slot = Bet::storage().distributed_amount.slot;
    let distributed_amount: U128 = storage_read(bet_contract_address,distributed_amount_slot, block_number );
    std::println(f"distributed_amount: {distributed_amount}");
    assert(distributed_amount == U128::from_integer(expected_distributed_amount), "incorrect distributed_amount");
}
