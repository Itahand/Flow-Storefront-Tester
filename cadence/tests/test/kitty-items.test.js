import path from "path";

import {
	emulator,
	init,
	getAccountAddress,
	shallPass,
	shallResolve,
	shallRevert,
} from "@onflow/flow-js-testing";

import { getPhilosophersAdminAddress } from "../src/common";
import {
	deployPhilosophers,
	getPhilosopherCount,
	getPhilosophersNFTupply,
	mintPhilosopher,
	setupPhilosophersNFTOnAccount,
	transferPhilosopher,
	types,
	rarities,
} from "../src/philosophers";

// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(100000);

describe("PhilosophersNFT", () => {
	// Instantiate emulator and path to Cadence files
	beforeEach(async () => {
		const basePath = path.resolve(__dirname, "../../");
		await init(basePath);
		await emulator.start();
	});

	// Stop emulator, so it could be restarted
	afterEach(async () => {
		await emulator.stop();
	});

	it("should deploy PhilosofersNFT contract", async () => {
		await shallPass(deployPhilosophers());
	});

	it("supply should be 0 after contract is deployed", async () => {
		// Setup
		await deployPhilosophers();
		const PhilosophersAdmin = await getPhilosophersAdminAddress();
		await shallPass(setupPhilosophersNFTOnAccount(PhilosophersAdmin));

		const [supply] = await shallResolve(getPhilosophersNFTupply())
		expect(supply).toBe("0");
	});

	it("should be able to mint a philosopher", async () => {
		// Setup
		await deployPhilosophers();
		const Alice = await getAccountAddress("Alice");
		await setupPhilosophersNFTOnAccount(Alice);

		// Mint instruction for Alice account shall be resolved
		await shallPass(mintPhilosopher(Alice, types.socrates, rarities.common));
	});

	it("should be able to create a new empty NFT Collection", async () => {
		// Setup
		await deployPhilosophers();
		const Alice = await getAccountAddress("Alice");
		await setupPhilosophersNFTOnAccount(Alice);

		// shall be able te read Alice collection and ensure it's empty
		const [itemCount] = await shallResolve(getPhilosopherCount(Alice))
		expect(itemCount).toBe("0");
	});

	it("should not be able to withdraw an NFT that doesn't exist in a collection", async () => {
		// Setup
		await deployPhilosophers();
		const Alice = await getAccountAddress("Alice");
		const Bob = await getAccountAddress("Bob");
		await setupPhilosophersNFTOnAccount(Alice);
		await setupPhilosophersNFTOnAccount(Bob);

		// Transfer transaction shall fail for non-existent item
		await shallRevert(transferPhilosopher(Alice, Bob, 1337));
	});

	it("should be able to withdraw an NFT and deposit to another accounts collection", async () => {
		await deployPhilosophers();
		const Alice = await getAccountAddress("Alice");
		const Bob = await getAccountAddress("Bob");
		await setupPhilosophersNFTOnAccount(Alice);
		await setupPhilosophersNFTOnAccount(Bob);

		// Mint instruction for Alice account shall be resolved
		await shallPass(mintPhilosopher(Alice, types.socrates, rarities.common));

		// Transfer transaction shall pass
		await shallPass(transferPhilosopher(Alice, Bob, 0));
	});

	it("misc test", async () => {

	})
});
