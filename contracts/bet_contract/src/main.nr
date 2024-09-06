mod test;
mod bet_note;


// The only thing hidden is address who bets!
contract Bet {
    use crate::bet_note::{BetNote};

    use dep::aztec::{
        prelude::{Map, PublicMutable, PublicImmutable, SharedImmutable, AztecAddress, PrivateSet},
        encrypted_logs::encrypted_note_emission::{encode_and_encrypt_note, encode_and_encrypt_note_with_keys},
        keys::getters::get_current_public_keys,
        note::utils::compute_note_hash_for_nullify,
    };
    use dep::token::Token;

    global NUM_COINS = 10; 

    // CONTRACT CAN ONLY BE USED ONCE!
    #[aztec(storage)]
    struct Storage {
        coins: Map<AztecAddress, PublicMutable<bool>>, //TODO: Need names?
        bets: Map<AztecAddress, PublicMutable<U128>>, //can't compare with fields!
        bet_coin_accepted: SharedImmutable<AztecAddress>,
        expiry_block_number: PublicImmutable<u32>,
        winner_coin: PublicImmutable<AztecAddress>, // coin with most bets
        loser_coin: PublicImmutable<AztecAddress>, // coin with least bets
        distributed_amount: PublicImmutable<U128>,
        bet_receipts: PrivateSet<BetNote>, // TODO make this a map!

    }

    #[aztec(public)]
    #[aztec(initializer)]
    // has to be a field for CLI tests
    fn constructor(coins: [AztecAddress; NUM_COINS], expiry_block_number: u32, bet_coin_accepted: AztecAddress) {
        for i in 0 .. NUM_COINS {
            storage.coins.at(coins[i]).write(true);
        }
        storage.expiry_block_number.initialize(expiry_block_number);
        storage.bet_coin_accepted.initialize(bet_coin_accepted);

    }

    #[aztec(private)]
    fn bet(amount: Field, coin: AztecAddress) {
        let gambler = context.msg_sender();
        Token::at(storage.bet_coin_accepted.read_private()).unshield(gambler,context.this_address(),amount,0).call(&mut context);
        Bet::at(context.this_address())._update_bet(amount, coin).enqueue(&mut context);

        // create receipt note:
        let gambler_keys = get_current_public_keys(&mut context, gambler);
        let mut note = BetNote::new(amount, gambler_keys.npk_m.hash(), coin);
        storage.bet_receipts.insert(&mut note).emit(encode_and_encrypt_note_with_keys(&mut context, gambler_keys.ovpk_m, gambler_keys.ivpk_m, gambler));
    }

    // The bet amount is public. There is no way round it since the current coin balance has to be public too 
    // so someone else (admin or you!) can come and check who the winner is transparently
    #[aztec(public)]
    #[aztec(internal)]
    fn _update_bet(amount: Field, coin: AztecAddress) {
        assert(storage.coins.at(coin).read() == true, "coin incorrect");
        assert((context.block_number()) as u32 <= storage.expiry_block_number.read() as u32, "expired");
        let new_balance = storage.bets.at(coin).read().add(U128::from_integer(amount));
        storage.bets.at(coin).write(new_balance);
    }

    #[aztec(public)]
    fn announce_winner_and_loser(coins: [AztecAddress; NUM_COINS]) {
        // asser not called already
        assert(storage.winner_coin.read() == AztecAddress::zero(), "looks like winner was already decided");
        assert(storage.loser_coin.read() == AztecAddress::zero(), "looks like loser was already decided");
        // assert expired
        assert((context.block_number()) as u32 > storage.expiry_block_number.read() as u32, "not expired");
        
        // go through each coin and check which coin has most and least bets. 
        // Also count the amount of funds from the middle 8 coins that need to be rugged!
        let first_coin = coins[0];
        assert(storage.coins.at(first_coin).read() == true, "incorrect first coin");
        let mut winner_coin_index = 0;
        let mut loser_coin_index = 0;
        let mut winner_balance = storage.bets.at(first_coin).read();
        let mut loser_balance = winner_balance; // is this deep copy?
        let mut total_amount: U128 = winner_balance;

        for i in 1 .. NUM_COINS {
            // noir doesn't let you store arrays so instead pass as a param and check that it matches storage.
            assert(storage.coins.at(coins[i]).read() == true, "incorrect coin");
            let coin_bal =  storage.bets.at(coins[i]).read();  
            total_amount += coin_bal;

            // keep a running flow of top winner and top loser
            if (winner_balance < coin_bal) {
                winner_balance = coin_bal;
                winner_coin_index = i;
            } else if loser_balance > coin_bal {
                loser_balance = coin_bal;
                loser_coin_index = i;
            }
        }

        storage.winner_coin.initialize(coins[winner_coin_index]);
        storage.loser_coin.initialize(coins[loser_coin_index]);
        //  amount to rug = balance from mid 8 coins. This is equally distributed b/w winner and loser coin.
        let rugged_amount = total_amount - loser_balance - winner_balance;
        let distributed_amount = rugged_amount / U128::from_integer(2); //TODO: Precision?

        // Update winner and loser amount:
        storage.distributed_amount.initialize(distributed_amount);
    }

    // #[aztec(private)]
    // fn claim_coins(proof_note: BetNote, recipient: AztecAddress) {
    //     // 1) Check that the note comes from this address
    //     assert(
    //         context.this_address() == proof_note.header.contract_address, "Note does not correspond to this contract"
    //     );

    //     // 2) Prove that the note hash exists in the note hash tree
    //     let header = context.get_header();
    //     header.prove_note_inclusion(proof_note);

    //     // 3) Compute and emit a nullifier which is unique to the note and this contract to ensure the reward can be
    //     // claimed only once with the given note.
    //     // Note: Only the owner of the npk_m will be able to produce the nsk_app and compute this nullifier.
    //     // The nullifier is unique to the note and THIS contract because the protocol siloes all nullifiers with
    //     // the address of a contract it was emitted from.
    //     let note_hash_for_nullify = compute_note_hash_for_nullify(proof_note);
    //     let nullifier = proof_note.compute_nullifier(&mut context, note_hash_for_nullify);
    //     context.push_nullifier(nullifier);

    //      Bet::at(context.this_address())._give_rewards(amount_betted, coin_betted, recipient).enqueue(&mut context);

    // }

    #[aztec(private)]
    fn claim_coins(amount_betted: Field, coin_betted: AztecAddress, recipient: AztecAddress) {
        Bet::at(context.this_address())._give_rewards(amount_betted, coin_betted, recipient).enqueue(&mut context);
    }

    // give rewards proportial to how much you bet (your_amt * distributed_amount / coin_bal)
    // This leaks how much you bet. But that was leaked previously anyway and you get bragging rights!
    // The other alternatives are:
    // 1. Make coin balances shared in both private and public -> extremely messy!
    // 2. pass coin balance and verify in public.
    // Since for now i have decided to do this in public, might as well mint coins publicly. 
    // Partial notes would let me mint coins privately but it would still leak the bet amount!
    #[aztec(public)]
    #[aztec(internal)]
    fn _give_rewards(amount_betted: U128, coin_betted: AztecAddress, recipient: AztecAddress) {
        // these checks could be done in private for better UX (transaction generation just fails)
        // but this saves proving time. Ideally you only call this only if you know you won!

        // assert expired
        assert((context.block_number()) as u32 > storage.expiry_block_number.read() as u32, "not expired: _vice_rewards");
        let distributed_amount = storage.distributed_amount.read();
        assert(distributed_amount != U128::zero(), "looks like winner hasn't been decided");

        // check note is for either the winner or loser!
        let x: bool = coin_betted == storage.winner_coin.read();
        let y: bool = coin_betted == storage.loser_coin.read();
        assert (x | y, "neither winner nor loser. Can't claim!");

        let amount_won: U128 = (amount_betted * distributed_amount) / storage.bets.at(coin_betted).read();
        let amount_to_transfer = amount_betted + amount_won;

        // transfer to person
        Token::at(storage.bet_coin_accepted.read_public()).transfer_public(context.this_address(), recipient, amount_to_transfer.to_field(), 0);
    }
}



