import { mintFlow, executeScript, sendTransaction, deployContractByName } from "@onflow/flow-js-testing";
import { getPhilosophersAdminAddress } from "./common";

export const types = {
	socrates: 1,
	spinoza: 2,
	nietzsche: 3
};

export const rarities = {
	common: 1,
	rare: 2,
	epic: 3
};

/*
 * Deploys NonFungibleToken and PhilosophersNFT contracts to philosophersAdmin.
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<[{*} txResult, {error} error]>}
 * */
export const deployPhilosophers = async () => {
	const philosophersAdmin = await getPhilosophersAdminAddress();
	await mintFlow(philosophersAdmin, "10.0");

	await deployContractByName({ to: philosophersAdmin, name: "NonFungibleToken" });
	await deployContractByName({ to: philosophersAdmin, name: "MetadataViews" });
	return deployContractByName({ to: philosophersAdmin, name: "PhilosophersNFT" });
};

/*
 * Setups PhilosophersNFT collection on account and exposes public capability.
 * @param {string} account - account address
 * @returns {Promise<[{*} txResult, {error} error]>}
 * */
export const setupPhilosophersNFTOnAccount = async (account) => {
	const name = "PhilosophersNFT/setup_account";
	const signers = [account];

	return sendTransaction({ name, signers });
};

/*
 * Returns PhilosophersNFT supply.
 * @throws Will throw an error if execution will be halted
 * @returns {UInt64} - number of NFT minted so far
 * */
export const getPhilosophersNFTupply = async () => {
	const name = "PhilosophersNFT/get_philosophers_supply";

	return executeScript({ name });
};

/*
 * Mints Philosopher of a specific **itemType** and sends it to **recipient**.
 * @param {UInt64} itemType - type of NFT to mint
 * @param {string} recipient - recipient account address
 * @returns {Promise<[{*} result, {error} error]>}
 * */
export const mintPhilosopher = async (recipient, itemType, itemRarity, cuts = [], royaltyDescriptions = [], royaltyBeneficiaries = []) => {
	const philosophersAdmin = await getPhilosophersAdminAddress();

	const name = "PhilosophersNFT/mint_philosopher";
	const args = [recipient, itemType, itemRarity, cuts, royaltyDescriptions, royaltyBeneficiaries];
	const signers = [philosophersAdmin];

	return sendTransaction({ name, args, signers });
};

/*
 * Transfers Philosopher NFT with id equal **itemId** from **sender** account to **recipient**.
 * @param {string} sender - sender address
 * @param {string} recipient - recipient address
 * @param {UInt64} itemId - id of the item to transfer
 * @throws Will throw an error if execution will be halted
 * @returns {Promise<*>}
 * */
export const transferPhilosopher = async (sender, recipient, itemId) => {
	const name = "PhilosophersNFT/transfer_philosopher";
	const args = [recipient, itemId];
	const signers = [sender];

	return sendTransaction({ name, args, signers });
};

/*
 * Returns the Philosopher NFT with the provided **id** from an account collection.
 * @param {string} account - account address
 * @param {UInt64} itemID - NFT id
 * @throws Will throw an error if execution will be halted
 * @returns {UInt64}
 * */
export const getPhilosopher = async (account, itemID) => {
	const name = "PhilosophersNFT/get_philosopher";
	const args = [account, itemID];

	return executeScript({ name, args });
};

/*
 * Returns the number of Kitty Items in an account's collection.
 * @param {string} account - account address
 * @throws Will throw an error if execution will be halted
 * @returns {UInt64}
 * */
export const getPhilosopherCount = async (account) => {
	const name = "PhilosophersNFT/get_collection_length";
	const args = [account];

	return executeScript({ name, args });
};
