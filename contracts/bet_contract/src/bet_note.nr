use dep::aztec::{
    protocol_types::{
    address::AztecAddress, traits::{Deserialize, Serialize}, constants::GENERATOR_INDEX__NOTE_NULLIFIER,
    hash::poseidon2_hash_with_separator
},
    note::{note_header::NoteHeader, note_interface::NoteInterface, utils::compute_note_hash_for_nullify},
    oracle::unsafe_rand::unsafe_rand, keys::getters::get_nsk_app, context::PrivateContext
};

global BET_NOTE_LEN: Field = 4;
// BET_NOTE_LEN * 32 + 32(storage_slot as bytes) + 32(note_type_id as bytes)
global BET_NOTE_BYTES_LEN: Field = 4 * 32 + 64;

#[aztec(note)]
struct BetNote {
    amount: Field,
    npk_m_hash: Field, 
    coin_betted: AztecAddress,
    randomness: Field,
}

impl BetNote {
    pub fn new(amount: Field, npk_m_hash: Field, coin_betted: AztecAddress ) -> Self {
        let randomness = unsafe_rand();
        let header = NoteHeader::empty();
        BetNote { amount, npk_m_hash, coin_betted, randomness, header }
    }
}

impl NoteInterface<BET_NOTE_LEN, BET_NOTE_BYTES_LEN> for BetNote {
    fn compute_nullifier(self, context: &mut PrivateContext, note_hash_for_nullify: Field) -> Field {
        let secret = context.request_nsk_app(self.npk_m_hash);
        poseidon2_hash_with_separator([
            note_hash_for_nullify,
            secret
        ],
            GENERATOR_INDEX__NOTE_NULLIFIER as Field,
        )
    }

    fn compute_nullifier_without_context(self) -> Field {
        let note_hash_for_nullify = compute_note_hash_for_nullify(self);
        let secret = get_nsk_app(self.npk_m_hash);
        poseidon2_hash_with_separator([
            note_hash_for_nullify,
            secret,
        ],
            GENERATOR_INDEX__NOTE_NULLIFIER as Field,
        )
    }
}

// impl Serialize<8> for BetNote {
//     /// The following method needed to be implemented because the note is passed as an argument to a contract function
//     /// --> the serialize method is called by aztec-nr when computing an arguments hash.
//     /// Note that when the note is about to be encrypted and emitted as a log the to_be_bytes function auto-implemented
//     /// by aztec macros is called instead.
//     fn serialize(self) -> [Field; 8] {
//         let header = self.header.serialize();
//         [self.amount, self.npk_m_hash, self.coin_betted.to_field(), self.randomness, header[0], header[1], header[2], header[3]]
//     }
// }

impl Eq for BetNote {
    fn eq(self, other: Self) -> bool {
        (self.amount == other.amount) &
        (self.npk_m_hash == other.npk_m_hash) &
        (self.coin_betted == other.coin_betted) &
        (self.randomness == other.randomness)
    }
}