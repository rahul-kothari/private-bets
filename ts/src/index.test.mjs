
import { waitForPXE, createPXEClient } from "@aztec/aztec.js";
import { getInitialTestAccountsWallets } from "@aztec/accounts/testing"
import { TokenContract } from '@aztec/noir-contracts.js/Token';

const {
    PXE_URL = "http://localhost:8080",
    ETHEREUM_HOST = "http://localhost:8545",
  } = process.env;

describe("Bet", () => {
    let pxe;
    let wallets = [];
    let accounts = [];
    let tokenContract;

    let user;
    let user2;

    beforeAll(async () => {
        pxe = createPXEClient(PXE_URL);
        await waitForPXE(pxe);

        wallets = await getInitialTestAccountsWallets(pxe);
        accounts = wallets.map(w => w.getCompleteAddress());
        user = wallets[0];
        user2 = wallets[1];


        // deploy Token
        tokenContract = await TokenContract.deploy(user, user.getAddress(), "TestToken0000000000000000000000","TT00000000000000000000000000000",18).send().deployed();

        // deploy Bet

        // mint token to accounts
    });

    it("hi", () => {

    });

});