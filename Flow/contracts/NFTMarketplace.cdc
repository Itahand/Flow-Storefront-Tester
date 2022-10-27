import NonFungibleToken from "./NonFungibleToken.cdc"
import NPMContract from "./NPMContract.cdc"
import FungibleToken from "./FungibleToken.cdc"
import FlowToken from "./FlowToken.cdc"

pub contract NFTMarketplace {

    // -----------------------------------------------------------------------
    // NFTMarketplace contract Event definitions
    // -----------------------------------------------------------------------
    // Emitted when a NFT is listed from sale
    pub event NPMListed(id: UInt64, price: UFix64, owner: Address?)
    // Emitted when a NFT is removed from sale
    pub event NPMRemoved(id: UInt64, owner: Address?)
    //  Emitted when a NFT is purchased
    pub event NPMPurchased(id: UInt64, price: UFix64, owner: Address?, to: Address?)
    // Emitted when the price of a listed NFT has changed
    pub event NPMPriceChanged(id: UInt64, newPrice: UFix64, owner: Address? )
    // Emitted when the cut percentage of the sale has been changed by the owner
    pub event CutPercentageChanged(newPercent: UFix64, owner: Address?)

    // Contract level paths for storing resources
    pub let SaleCollectionStoragePath: StoragePath
    pub let AdminResourceStoragePath: StoragePath
    pub let AdminResourcePublicPath: PublicPath
    pub let SaleCollectionPublicPath: PublicPath
    pub let SaleCollectionPrivatePath: PrivatePath

    // NFTMarketplace state level variables 
    // The Vault of the Marketplace where it will receive the cuts on each sale
    pub let marketplaceWallet: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
    
    //dictionary to store the all listing NPM of users
    access(contract) var allListingNPMs: {Address: {UInt64: ListingItemPublic}}

    // These will be used in the Marketplace to pay out
    // royalties to the creator and to the marketplace
    access(contract) var royaltyCut: UFix64
    access(contract) var marketplaceCut: UFix64

    // ListingItemPublic 
    //
    // The structure that hold tha data user sale item
    // to allow others to access their sale
    pub struct ListingItemPublic{
        pub let ownerAddress: Address
        pub var price: UFix64
        pub var metadata: {String: AnyStruct}
        pub let tokenID : UInt64

        init(ownerAddress: Address, price: UFix64, metadata:  {String: AnyStruct}, tokenID : UInt64) {
            self.ownerAddress = ownerAddress
            self.price = price
            self.metadata = metadata
            self.tokenID = tokenID
            }

            pub fun updataPrice(price: UFix64){
                self.price = price
            }
}
    // SalePublic 
    //
    // The interface that a user can publish a capability to their sale
    // to allow others to access their sale
    pub resource interface SalePublic {
        pub fun purchaseNPMWithFlow(tokenID: UInt64, recipientCap: Capability<&{NPMContract.NPMContractCollectionPublic}>, buyTokens: @FungibleToken.Vault)
        pub fun purchaseNPM(tokenID: UInt64, recipientCap: Capability<&{NPMContract.NPMContractCollectionPublic}>)
        pub fun getPrice(tokenID: UInt64): UFix64?
        pub fun getIDs(): [UInt64]
        pub fun borrowNPM(id: UInt64): &NPMContract.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id): 
                    "Cannot borrow Moment reference: The ID of the returned reference is incorrect"
            }
        }
    }


    // SaleCollection
    //
    // This is the main resource that token sellers will store in their account
    // to manage the NFTs that they are selling. 
    // NFT Collection object that allows a user to put their NFT up for sale
    // where others can send fungible tokens to purchase it
    pub resource SaleCollection: SalePublic {

        // Dictionary of the NFTs that the user is putting up for sale
        pub var forSale: @{UInt64: NPMContract.NFT}
        // Dictionary of the flow prices for each NFT by ID
        access(self) var prices: {UInt64: UFix64}

        // The fungible token vault of the owner of this sale.
        // When someone buys a token, this resource can deposit
        // tokens into their account.
        access(account) let ownerVault: Capability<&FlowToken.Vault{FungibleToken.Receiver}>

        // The percentage that is taken from every purchase for the beneficiary
        // For example, if the percentage is 10%, cutPercentage = 0.10
        pub var cutPercentage: UFix64


        init (vault: Capability<&FlowToken.Vault{FungibleToken.Receiver}>) {
            pre {
                // Check that both capabilities are for fungible token Vault receivers
                vault.check(): 
                    "Owner's Receiver Capability is invalid!"
            }
            
            // create an empty collection to store the moments that are for sale
            self.forSale <-{}
            self.ownerVault = vault
            // prices are initially empty because there are no moments for sale
            self.prices = {}
            self.cutPercentage = 0.10
        }

        // listForSale lists an NPM for sale in this sale collection
        // at the specified price
        //
        // Parameters: token: The NPM to be put up for sale
        //             price: The price of the NPM
        pub fun listForSale(token: @NPMContract.NFT, price: UFix64) {
            // get the ID of the token
            let id = token.id
            // Set the token's price
            self.prices[token.id] = price
            let name = token.name
            let description = token.description
            let thumbnail = token.thumbnail
            let author = token.author
            let data = token.data
            let metadata: {String: AnyStruct} = {"name": name, "description": description, "thumbnail": thumbnail, "data": data, "author": author}
            let oldToken <- self.forSale[id] <- token

            let Saledata =  NFTMarketplace.ListingItemPublic(ownerAddress: self.owner!.address, price: price, metadata: metadata, tokenID: id)
            if(NFTMarketplace.allListingNPMs[self.owner!.address] == nil){
                NFTMarketplace.allListingNPMs.insert(key: self.owner!.address, {id: Saledata})
            }else {
                NFTMarketplace.allListingNPMs[self.owner!.address]!.insert(key: id,  Saledata)
            }

            destroy oldToken

            emit NPMListed(id: id, price: price, owner: self.owner?.address)
        }

        // Withdraw removes a NPM that was listed for sale
        // and clears its price
        //
        // Parameters: tokenID: the ID of the token to withdraw from the sale
        //
        // Returns: @NPMContract.NFT: The nft that was withdrawn from the sale
        pub fun withdraw(tokenID: UInt64): @NPMContract.NFT {
            // remove the price
            self.prices.remove(key: tokenID)
            // remove and return the token
            let token <- self.forSale.remove(key: tokenID) ?? panic("missing NFT")
            NFTMarketplace.allListingNPMs[self.owner!.address]!.remove(key: tokenID) 

            emit NPMRemoved(id: tokenID, owner: self.owner!.address)
            return <-token
        }

        // purchase lets a user send tokens to purchase an NPM that is for sale
        // the purchased NPM is returned to the transaction context that called it
        //
        // Parameters: tokenID: the ID of the NPM to purchase
        //             butTokens: the fungible tokens that are used to buy the NFT
        pub fun purchaseNPMWithFlow(tokenID: UInt64, recipientCap: Capability<&{NPMContract.NPMContractCollectionPublic}>, buyTokens: @FungibleToken.Vault) {
            pre {
                self.forSale[tokenID] != nil && self.prices[tokenID] != nil: "No token matching this ID for sale!"           
                buyTokens.balance >= (self.prices[tokenID] ?? UFix64(0)): "Not enough tokens to buy the NFT!"
            }
            let recipient = recipientCap.borrow()!
            // Read the price for the token
            let price = self.prices[tokenID]!
            // Set the price for the token to nil
            self.prices[tokenID] = nil
            let vaultRef = self.ownerVault.borrow() ??panic("could not borrow reference to the owner vault")
            let token <- self.withdraw(tokenID: tokenID)
            let author = token.author
            let marketplaceWallet = NFTMarketplace.marketplaceWallet.borrow()!
            let marketplaceAmount = price * NFTMarketplace.marketplaceCut
            let royaltyAmount = price * NFTMarketplace.royaltyCut
            let tempMarketplaceWallet <- buyTokens.withdraw(amount: marketplaceAmount)
            let temproyaltyWallet <- buyTokens.withdraw(amount: royaltyAmount)

            let creatorVault = getAccount(author)
                                .getCapability(/public/flowTokenReceiver)
                                .borrow<&{FungibleToken.Receiver}>()
                                ?? panic("Unable to borrow creator reference")

            marketplaceWallet.deposit(from: <- tempMarketplaceWallet)
            creatorVault.deposit(from: <- temproyaltyWallet)

            vaultRef.deposit(from: <- buyTokens)
            recipient.deposit(token: <- token)
            NFTMarketplace.allListingNPMs[self.owner!.address]!.remove(key: 1)

            emit NPMPurchased(id: tokenID, price: price, owner: self.owner?.address, to: recipient.owner!.address)
        }

        // purchase lets a user send tokens to purchase an NPM that is for sale
        // the purchased NPM is returned to the transaction context that called it
        //
        // Parameters: tokenID: the ID of the NPM to purchase
         pub fun purchaseNPM(tokenID: UInt64, recipientCap: Capability<&{NPMContract.NPMContractCollectionPublic}>){
            pre {
                self.forSale[tokenID] != nil && self.prices[tokenID] != nil: "No token matching this ID for sale!"
            }
            let recipient = recipientCap.borrow()!
            // Read the price for the token
            let price = self.prices[tokenID]!
            // Set the price for the token to nil
            self.prices[tokenID] = nil
            let token <- self.withdraw(tokenID: tokenID)

            recipient.deposit(token: <- token)
            NFTMarketplace.allListingNPMs[self.owner!.address]!.remove(key: 1)

            emit NPMPurchased(id: tokenID, price: price, owner: self.owner?.address, to: recipient.owner!.address)
         }

        // changePrice changes the price of a token that is currently for sale
        //
        // Parameters: tokenID: The ID of the NPM's price that is changing
        //             newPrice: The new price for the NPM
        pub fun changePrice(tokenID: UInt64, newPrice: UFix64) {
            pre {
                self.prices[tokenID] != nil: "Cannot change the price for a token that is not for sale"
                newPrice > UFix64(0.0): "new price should be greater then 0.0"
            }
            // Set the new price
            self.prices[tokenID] = newPrice
            NFTMarketplace.allListingNPMs[self.owner!.address]![tokenID]!.updataPrice(price: newPrice)
           
            emit NPMPriceChanged(id: tokenID, newPrice: newPrice, owner: self.owner?.address)
        }

        // changePercentage changes the cut percentage of the tokens that are for sale
        //
        // Parameters: newPercent: The new cut percentage for the sale
        pub fun changePercentage(_ newPercent: UFix64) {
            pre {
                newPercent <= 1.0: "Cannot set cut percentage to greater than 100%"
            }
            self.cutPercentage = newPercent

            emit CutPercentageChanged(newPercent: newPercent, owner: self.owner?.address)
        }

        // getPrice returns the price of a specific token in the sale
        // 
        // Parameters: tokenID: The ID of the NFT whose price to get
        //
        // Returns: UFix64: The price of the token
        pub fun getPrice(tokenID: UInt64): UFix64? {
            return self.prices[tokenID]
        }
        
        // method to get the cut Percentage
        pub fun getPercentage(): UFix64 {
            return self.cutPercentage
        }

        // method getIDs returns an array of token IDs that are for sale
        pub fun getIDs(): [UInt64] {
            return self.forSale.keys
        }

        // borrowM Returns a borrowed reference to a NPM in the collection
        // so that the caller can read data from it
        //
        // Parameters: id: The ID of the moment to borrow a reference to
        //
        // Returns: &NPMContract.NFT? Optional reference to a moment for sale 
        //                        so that the caller can read its data
        //
        pub fun borrowNPM(id: UInt64): &NPMContract.NFT? {
            if self.forSale[id] != nil{
                return (&self.forSale[id] as &NPMContract.NFT?)!
            }
            else {
                return  nil   
            }
        }

        // If the sale collection is destroyed, 
        // destroy the tokens that are for sale inside of it
        destroy() {
            destroy self.forSale
        }
    }

    pub resource AdminResource {
        // Only Admins will be able to call the set functions to
        // manage Royalties and Marketplace cuts.
        pub fun setRoyaltyCut(value: UFix64){
            NFTMarketplace.royaltyCut = value
        }
        pub fun setMarketplaceCut(value: UFix64){
            NFTMarketplace.marketplaceCut = value
        }
    }
    // createCollection returns a new collection resource to the caller
    pub fun createSaleCollection(ownerVault: Capability<&FlowToken.Vault{FungibleToken.Receiver}>): @SaleCollection {
        return <- create SaleCollection(vault: ownerVault)
    }

    

    // These functions will return the current Royalty cuts for
    // both the Creator and the Marketplace.
    pub fun getRoyaltyCut(): UFix64{
        return self.royaltyCut
    }
    pub fun getMarketplaceCut(): UFix64{
        return self.marketplaceCut
    }

    // method to get all the listing NPM's
    pub fun getAllListingNMPs(): {Address: {UInt64: NFTMarketplace.ListingItemPublic}} {
        pre {
            NFTMarketplace.allListingNPMs != nil: "NPM does not exist"
        }
        return NFTMarketplace.allListingNPMs
    }

    // method to get the specific user Listing NPM's
    pub fun getAllListingNMPsByUser(user: Address): {UInt64: NFTMarketplace.ListingItemPublic} {
        pre {
            NFTMarketplace.allListingNPMs != nil: "NPM does not exist"
            user != nil: "user address should be vaild"
        }
        return NFTMarketplace.allListingNPMs[user]!
    }

    init() {
        self.allListingNPMs = {}
        self.royaltyCut = 0.01
        self.marketplaceCut = 0.05

        self.marketplaceWallet = self.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)

        self.SaleCollectionStoragePath = /storage/NPMSaleCollection
        self.AdminResourceStoragePath = /storage/AdminResourceStoragePath
        self.AdminResourcePublicPath = /public/NPMSaleCollection
        self.SaleCollectionPublicPath = /public/NPMSaleCollection
        self.SaleCollectionPrivatePath = /private/NPMSaleCollection

        self.account.save(<- create AdminResource(), to: self.AdminResourceStoragePath)

        
    }
}