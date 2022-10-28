import NonFungibleToken from "../../contracts/NonFungibleToken.cdc"
import PhilosophersNFT from "../../contracts/PhilosophersNFT.cdc"
import MetadataViews from "../../contracts/MetadataViews.cdc"

// This transaction configures an account to hold Kitty Items.

transaction {
    prepare(signer: AuthAccount) {
        // if the account doesn't already have a collection
        if signer.borrow<&PhilosophersNFT.Collection>(from: PhilosophersNFT.CollectionStoragePath) == nil {

            // create a new empty collection
            let collection <- PhilosophersNFT.createEmptyCollection()

            // save it to the account
            signer.save(<-collection, to: PhilosophersNFT.CollectionStoragePath)

            // create a public capability for the collection
            signer.link<&PhilosophersNFT.Collection{NonFungibleToken.CollectionPublic, PhilosophersNFT.PhilosophersNFTCollectionPublic, MetadataViews.ResolverCollection}>(PhilosophersNFT.CollectionPublicPath, target: PhilosophersNFT.CollectionStoragePath)
        }
    }
}
