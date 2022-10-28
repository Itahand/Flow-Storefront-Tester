import { deployContractByName, sendTransaction, executeScript } from "@onflow/flow-js-testing"
import { getPhilosophersAdminAddress } from "./common";
import { deployPhilosophers, setupPhilosophersNFTOnAccount } from "./philosophers";

/*
 * Deploys Philosophers]cx and NFTStorefrontV2 contracts to PhilosophersAdmin.
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<[{*} txResult, {error} error]>}
 * */
export const deployNFTStorefront = async () => {
	const PhilosophersAdmin = await getPhilosophersAdminAddress();
	await deployPhilosophers();

	return deployContractByName({ to: PhilosophersAdmin, name: "NFTStorefrontV2" });
};

/*
 * Sets up NFTStorefrontV2.Storefront on account and exposes public capability.
 * @param {string} account - account address
 * @throws Will throw an error if transaction is reverted.
 * @returns {Promise<[{*} txResult, {error} error]>}
 * */
export const setupStorefrontOnAccount = async (account) => {
	// Account shall be able to store Kitty philosophers
	await setupPhilosophersNFTOnAccount(account);

	const name = "nftStorefront/setup_account";
	const signers = [account];

	return sendTransaction({ name, signers });
};

/*
 * Lists philosopher with id equal to **philosopher** id for sale with specified **price**.
 * @param {string} seller - seller account address
 * @param {UInt64} philosopherId - id of philosopher to sell
 * @param {UFix64} price - price
 * @returns {Promise<[{*} txResult, {error} error]>}
 * */
export const createListing = async (seller, philosopherId, price) => {
	const name = "nftStorefront/create_listing";
	const args = [philosopherId, price];
	const signers = [seller];

	return sendTransaction({ name, args, signers });
};

/*
 * Buys philosopher with id equal to **philosopher** id for **price** from **seller**.
 * @param {string} buyer - buyer account address
 * @param {UInt64} resourceId - resource uuid of philosopher to sell
 * @param {string} seller - seller account address
 * @returns {Promise<[{*} txResult, {error} error]>}
 * */
export const purchaseListing = async (buyer, resourceId, seller) => {
	const name = "nftStorefront/purchase_listing";
	const args = [resourceId, seller];
	const signers = [buyer];

	return sendTransaction({ name, args, signers });
};

/*
 * Removes philosopher with id equal to **philosopher** from sale.
 * @param {string} owner - owner address
 * @param {UInt64} philosopherId - id of philosopher to remove
 * @returns {Promise<[{*} txResult, {error} error]>}
 * */
export const removeListing = async (owner, philosopherId) => {
	const name = "nftStorefront/remove_listing";
	const signers = [owner];
	const args = [philosopherId];

	return sendTransaction({ name, args, signers });
};

/*
 * Returns the number of philosophers for sale in a given account's storefront.
 * @param {string} account - account address
 * @returns {Promise<[{UInt64} result, {error} error]>}
 * */
export const getListingCount = async (account) => {
	const name = "nftStorefront/get_listings_length";
	const args = [account];

	return executeScript({ name, args });
};
