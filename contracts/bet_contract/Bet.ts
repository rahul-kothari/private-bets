
/* Autogenerated file, do not edit! */

/* eslint-disable */
import {
  AztecAddress,
  AztecAddressLike,
  CompleteAddress,
  Contract,
  ContractArtifact,
  ContractBase,
  ContractFunctionInteraction,
  ContractInstanceWithAddress,
  ContractMethod,
  ContractStorageLayout,
  ContractNotes,
  DeployMethod,
  EthAddress,
  EthAddressLike,
  EventSelector,
  FieldLike,
  Fr,
  FunctionSelectorLike,
  L1EventPayload,
  loadContractArtifact,
  NoirCompiledContract,
  NoteSelector,
  Point,
  PublicKey,
  Wallet,
  WrappedFieldLike,
} from '@aztec/aztec.js';
import BetContractArtifactJson from 'target/bet-Bet.json' assert { type: 'json' };
export const BetContractArtifact = loadContractArtifact(BetContractArtifactJson as NoirCompiledContract);



/**
 * Type-safe interface for contract Bet;
 */
export class BetContract extends ContractBase {
  
  private constructor(
    instance: ContractInstanceWithAddress,
    wallet: Wallet,
  ) {
    super(instance, BetContractArtifact, wallet);
  }
  

  
  /**
   * Creates a contract instance.
   * @param address - The deployed contract's address.
   * @param wallet - The wallet to use when interacting with the contract.
   * @returns A promise that resolves to a new Contract instance.
   */
  public static async at(
    address: AztecAddress,
    wallet: Wallet,
  ) {
    return Contract.at(address, BetContract.artifact, wallet) as Promise<BetContract>;
  }

  
  /**
   * Creates a tx to deploy a new instance of this contract.
   */
  public static deploy(wallet: Wallet, coins: AztecAddressLike[], expiry_block_number: (bigint | number), bet_coin_accepted: AztecAddressLike) {
    return new DeployMethod<BetContract>(Fr.ZERO, wallet, BetContractArtifact, BetContract.at, Array.from(arguments).slice(1));
  }

  /**
   * Creates a tx to deploy a new instance of this contract using the specified public keys hash to derive the address.
   */
  public static deployWithPublicKeysHash(publicKeysHash: Fr, wallet: Wallet, coins: AztecAddressLike[], expiry_block_number: (bigint | number), bet_coin_accepted: AztecAddressLike) {
    return new DeployMethod<BetContract>(publicKeysHash, wallet, BetContractArtifact, BetContract.at, Array.from(arguments).slice(2));
  }

  /**
   * Creates a tx to deploy a new instance of this contract using the specified constructor method.
   */
  public static deployWithOpts<M extends keyof BetContract['methods']>(
    opts: { publicKeysHash?: Fr; method?: M; wallet: Wallet },
    ...args: Parameters<BetContract['methods'][M]>
  ) {
    return new DeployMethod<BetContract>(
      opts.publicKeysHash ?? Fr.ZERO,
      opts.wallet,
      BetContractArtifact,
      BetContract.at,
      Array.from(arguments).slice(1),
      opts.method ?? 'constructor',
    );
  }
  

  
  /**
   * Returns this contract's artifact.
   */
  public static get artifact(): ContractArtifact {
    return BetContractArtifact;
  }
  

  public static get storage(): ContractStorageLayout<'admin' | 'minters' | 'balances' | 'total_supply' | 'pending_shields' | 'public_balances' | 'symbol' | 'name' | 'decimals'> {
      return {
        admin: {
      slot: new Fr(1n),
    },
minters: {
      slot: new Fr(2n),
    },
balances: {
      slot: new Fr(3n),
    },
total_supply: {
      slot: new Fr(4n),
    },
pending_shields: {
      slot: new Fr(5n),
    },
public_balances: {
      slot: new Fr(6n),
    },
symbol: {
      slot: new Fr(7n),
    },
name: {
      slot: new Fr(8n),
    },
decimals: {
      slot: new Fr(9n),
    }
      } as ContractStorageLayout<'admin' | 'minters' | 'balances' | 'total_supply' | 'pending_shields' | 'public_balances' | 'symbol' | 'name' | 'decimals'>;
    }
    

  public static get notes(): ContractNotes<'TransparentNote' | 'TokenNote'> {
    return {
      TransparentNote: {
          id: new NoteSelector(1049878767),
        },
TokenNote: {
          id: new NoteSelector(3992089675),
        }
    } as ContractNotes<'TransparentNote' | 'TokenNote'>;
  }
  

  /** Type-safe wrappers for the public methods exposed by the contract. */
  public override methods!: {
    
    /** compute_note_hash_and_optionally_a_nullifier(contract_address: struct, nonce: field, storage_slot: field, note_type_id: field, compute_nullifier: boolean, serialized_note: array) */
    compute_note_hash_and_optionally_a_nullifier: ((contract_address: AztecAddressLike, nonce: FieldLike, storage_slot: FieldLike, note_type_id: FieldLike, compute_nullifier: boolean, serialized_note: FieldLike[]) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** constructor(coins: array, expiry_block_number: integer, bet_coin_accepted: struct) */
    constructor: ((coins: AztecAddressLike[], expiry_block_number: (bigint | number), bet_coin_accepted: AztecAddressLike) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** bet(amount: field, coin: struct) */
    bet: ((amount: FieldLike, coin: AztecAddressLike) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** announce_winner_and_loser(coins: array) */
    announce_winner_and_loser: ((coins: AztecAddressLike[]) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** claim_coins() */
    claim_coins: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;
  };

  
}
