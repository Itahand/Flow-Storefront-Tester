import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import PhilosophersNFT from "../../contracts/PhilosophersNFT.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import FlowToken from "../../contracts/FlowToken.cdc"
//import MetadataViews from "../../contracts/MetadataViews.cdc"
import NFTStorefrontV2 from "../../contracts/NFTStorefrontV2.cdc"

// This transction uses the NFTMinter resource to mint a new NFT.

transaction(recipient: Address, philosopher: UInt8, rarity: UInt8) {
    // Mint

    // local variable for storing the minter reference
    let minter: &PhilosophersNFT.NFTMinter

    /// Reference to the receiver's collection
    let recipientCollectionRef: &{NonFungibleToken.CollectionPublic}

    /// Previous NFT ID before the transaction executes
    let mintingIDBefore: UInt64

    // List
    let flowReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
    let PhilosophersNFTProvider: Capability<&PhilosophersNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let storefront: &NFTStorefrontV2.Storefront
    var saleCuts: [NFTStorefrontV2.SaleCut]
    var marketplacesCapability: [Capability<&AnyResource{FungibleToken.Receiver}>]

    prepare(signer: AuthAccount) {
        // Prepare to mint
        self.mintingIDBefore = PhilosophersNFT.totalSupply

        // Borrow a reference to the NFTMinter resource in storage
        self.minter = signer.borrow<&PhilosophersNFT.NFTMinter>(from: PhilosophersNFT.MinterStoragePath)
            ?? panic("Could not borrow a reference to the NFT minter")

        // Borrow the recipient's public NFT collection reference
        self.recipientCollectionRef = getAccount(recipient)
            .getCapability(PhilosophersNFT.CollectionPublicPath)
            .borrow<&{NonFungibleToken.CollectionPublic}>()
            ?? panic("Could not get receiver reference to the NFT Collection")

        // Prepare to list
        self.saleCuts = []
        self.marketplacesCapability = []

        // We need a provider capability, but one is not provided by default so we create one if needed.
        let PhilosophersNFTCollectionProviderPrivatePath = /private/PhilosophersNFTCollectionProviderV14

        // Receiver for the sale cut.
        self.flowReceiver = signer.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)!

        assert(self.flowReceiver.borrow() != nil, message: "Missing or mis-typed FLOW receiver")

        // Check if the Provider capability exists or not if `no` then create a new link for the same.
        if !signer.getCapability<&PhilosophersNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(PhilosophersNFTCollectionProviderPrivatePath)!.check() {
            signer.link<&PhilosophersNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(PhilosophersNFTCollectionProviderPrivatePath, target: PhilosophersNFT.CollectionStoragePath)
        }

        self.PhilosophersNFTProvider = signer.getCapability<&PhilosophersNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(PhilosophersNFTCollectionProviderPrivatePath)!

        assert(self.PhilosophersNFTProvider.borrow() != nil, message: "Missing or mis-typed PhilosophersNFT.Collection provider")

        self.storefront = signer.borrow<&NFTStorefrontV2.Storefront>(from: NFTStorefrontV2.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefrontV2 Storefront")
    }

    execute {
        // Execute to mint
        let philosopherValue = PhilosophersNFT.Philosopher(rawValue: philosopher) ?? panic("invalid philosopher")
        let rarityValue = PhilosophersNFT.Rarity(rawValue: rarity) ?? panic("invalid rarity")

        // mint the NFT and deposit it to the recipient's collection
        self.minter.mintNFT(
            recipient: self.recipientCollectionRef,
            philosopher: philosopherValue,
            rarity: rarityValue,
            royalties: []
        )

        var totalRoyaltyCut = 0.0
        let effectiveSaleItemPrice = PhilosophersNFT.getItemPrice(rarity: rarityValue) // commission amount is 0

        // Skip this step - Check whether the NFT implements the MetadataResolver or not.

        // Append the cut for the seller
        self.saleCuts.append(NFTStorefrontV2.SaleCut(
            receiver: self.flowReceiver,
            amount: effectiveSaleItemPrice - totalRoyaltyCut
        ))

        // Execute to create listing
        self.storefront.createListing(
            nftProviderCapability: self.PhilosophersNFTProvider,
            nftType: Type<@PhilosophersNFT.NFT>(),
            nftID: PhilosophersNFT.totalSupply - 1,
            salePaymentVaultType: Type<@FlowToken.Vault>(),
            saleCuts: self.saleCuts,
            marketplacesCapability: self.marketplacesCapability.length == 0 ? nil : self.marketplacesCapability,
            customID: nil,
            commissionAmount: UFix64(0),
            expiry: UInt64(getCurrentBlock().timestamp) + UInt64(500)
        )
    }

    post {
        self.recipientCollectionRef.getIDs().contains(self.mintingIDBefore): "The next NFT ID should have been minted and delivered"
        PhilosophersNFT.totalSupply == self.mintingIDBefore + 1: "The total supply should have been increased by 1"
    }
}
