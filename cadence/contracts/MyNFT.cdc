import NonFungibleToken from "./NonFungibleToken.cdc"
import MetadataViews from "./MetadataViews.cdc"

pub contract MyNFT: NonFungibleToken {

    // totalSupply
    // The total number of MyNFT that have been minted
    //
  pub var totalSupply: UInt64

  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Minted(id: UInt64, philosopher: UInt8, rarity: UInt8)
  pub event ImagesAddedForNewPhilosopher(philosopher: UInt8)

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub enum Rarity: UInt8 {
      pub case common
      pub case rare
      pub case epic
    }

    pub fun rarityToString(_ rarity: Rarity): String {
        switch rarity {
            case Rarity.common:
                return "Common"
            case Rarity.rare:
                return "Rare"
            case Rarity.epic:
                return "Epic"
        }
        return ""
    }

    pub enum Philosopher: UInt8 {
        pub case socrates
        pub case spinoza
        pub case nietszche
    }

    pub fun philosopherToString(_ philosopher: philosopher): String {
        switch philosopher {
            case philosopher.socrates:
                return "Socrates"
            case philosopher.spinoza:
                return "Spinoza"
            case philosopher.nietszche:
                return "nietszche"
        }
        return ""
    }

    // Mapping from item (philosopher, rarity) -> IPFS image CID
    //
    access(self) var images: {philosopher: {Rarity: String}}

    // Mapping from rarity -> price
    //
    access(self) var itemRarityPriceMap: {Rarity: UFix64}

    // Return the initial sale price for an item of this rarity.
    //
    pub fun getItemPrice(rarity: Rarity): UFix64 {
        return self.itemRarityPriceMap[rarity]!
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64

        pub fun name(): String {
            return MyNFT.rarityToString(self.rarity)
                .concat(" ")
                .concat(MyNFT.philosopherToString(self.philosopher))
        }

        pub fun description(): String {
            return "A "
                .concat(MyNFT.rarityToString(self.rarity).toLower())
                .concat(" ")
                .concat(MyNFT.philosopherToString(self.philosopher).toLower())
                .concat(" with serial number ")
                .concat(self.id.toString())
        }

        pub fun imageCID(): String {
            return MyNFT.images[self.philosopher]![self.rarity]!
        }

        pub fun thumbnail(): MetadataViews.IPFSFile {
          return MetadataViews.IPFSFile(cid: self.imageCID(), path: "sm.png")
        }

        access(self) let royalties: [MetadataViews.Royalty]
        access(self) let metadata: {String: AnyStruct}

        // The token philosopher (e.g. socrates)
        pub let philosopher: Philosopher

        // The token rarity (e.g. Epic)
        pub let rarity: Rarity

        init(
            id: UInt64,
            royalties: [MetadataViews.Royalty],
            metadata: {String: AnyStruct},
            philosopher: Philosopher,
            rarity: Rarity,
        ){
            self.id = id
            self.royalties = royalties
            self.metadata = metadata
            self.philosopher = philosopher
            self.rarity = rarity
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name(),
                        description: self.description(),
                        thumbnail: self.thumbnail()
                    )
                case Type<MetadataViews.Editions>():
                    // There is no max number of NFTs that can be minted from this contract
                    // so the max edition field value is set to nil
                    let editionInfo = MetadataViews.Edition(name: "MyNFT NFT Edition", number: self.id, max: nil)
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(
                        editionList
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        self.royalties
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://kitty-items.flow.com/".concat(self.id.toString()))
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: MyNFT.CollectionStoragePath,
                        publicPath: MyNFT.CollectionPublicPath,
                        providerPath: /private/MyNFTCollection,
                        publicCollection: Type<&MyNFT.Collection{MyNFT.MyNFTCollectionPublic}>(),
                        publicLinkedType: Type<&MyNFT.Collection{MyNFT.MyNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&MyNFT.Collection{MyNFT.MyNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-MyNFT.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                        ),
                        mediaType: "image/svg+xml"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "The MyNFT Collection",
                        description: "This collection is used as an example to help you develop your next Flow NFT.",
                        externalURL: MetadataViews.ExternalURL("https://kitty-items.flow.com/"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/flow_blockchain")
                        }
                    )
                case Type<MetadataViews.Traits>():
                    // exclude mintedTime and foo to show other uses of Traits
                    let excludedTraits = ["mintedTime", "foo"]
                    let traitsView = MetadataViews.dictToTraits(dict: self.metadata, excludedNames: excludedTraits)

                    // mintedTime is a unix timestamp, we should mark it with a displayType so platforms know how to show it.
                    let mintedTimeTrait = MetadataViews.Trait(name: "mintedTime", value: self.metadata["mintedTime"]!, displayType: "Date", rarity: nil)
                    traitsView.addTrait(mintedTimeTrait)

                    // foo is a trait with its own rarity
                    let fooTraitRarity = MetadataViews.Rarity(score: 10.0, max: 100.0, description: "Common")
                    let fooTrait = MetadataViews.Trait(name: "foo", value: self.metadata["foo"], displayType: nil, rarity: fooTraitRarity)
                    traitsView.addTrait(fooTrait)

                    return traitsView

            }
            return nil
        }
    }

    // This is the interface that users can cast their MyNFT Collection as
    // to allow others to deposit MyNFT into their Collection. It also allows for reading
    // the details of MyNFT in the Collection.
    pub resource interface MyNFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowMyNFT(id: UInt64): &MyNFT.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow MyNFT reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection
    // A collection of MyNFT NFTs owned by an account
    //
    pub resource Collection: MyNFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        //
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // initializer
        //
        init () {
            self.ownedNFTs <- {}
        }

        // withdraw
        // removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit
        // takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @MyNFT.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs
        // returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT
        // gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // borrowMyNFT
        // Gets a reference to an NFT in the collection as a MyNFT,
        // exposing all of its fields (including the typeID & rarityID).
        // This is safe as there are no functions that can be called on the MyNFT.
        //
        pub fun borrowMyNFT(id: UInt64): &MyNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &MyNFT.NFT
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let MyNFT = nft as! &MyNFT.NFT
            return MyNFT as &AnyResource{MetadataViews.Resolver}
        }

        // destructor
        destroy() {
            destroy self.ownedNFTs
        }
    }

    // createEmptyCollection
    // public function that anyone can call to create a new empty collection
    //
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // NFTMinter
    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    pub resource NFTMinter {

        // mintNFT
        // Mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        //
        pub fun mintNFT(
            recipient: &{NonFungibleToken.CollectionPublic},
            philosopher: Philosopher,
            rarity: Rarity,
            royalties: [MetadataViews.Royalty],
        ) {
            let metadata: {String: AnyStruct} = {}
            let currentBlock = getCurrentBlock()
            metadata["mintedBlock"] = currentBlock.height
            metadata["mintedTime"] = currentBlock.timestamp
            metadata["minter"] = recipient.owner!.address

            // this piece of metadata will be used to show embedding rarity into a trait
            // metadata["foo"] = "bar"

            // create a new NFT
            var newNFT <- create MyNFT.NFT(
                id: MyNFT.totalSupply,
                royalties: royalties,
                metadata: metadata,
                philosopher: philosopher,
                rarity: rarity
            )

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)

            emit Minted(
                id: MyNFT.totalSupply,
                philosopher: philosopher.rawValue,
                rarity: rarity.rawValue,
            )

            MyNFT.totalSupply = MyNFT.totalSupply + UInt64(1)
        }

        // Update NFT images for new type
        pub fun addNewImagesForPhilosopher(from: AuthAccount, newImages: {Philosopher: {Rarity: String}}) {
            let philosopherValue = MyNFT.images.containsKey(newImages.keys[0])
            if(!philosopherValue) {
                MyNFT.images.insert(key: newImages.keys[0], newImages.values[0])
                emit ImagesAddedForNewPhilosopher(
                    philosopher: newImages.keys[0].rawValue,
                )
            } else {
                panic("No Rugs... Can't update existing NFT images.")
            }
        }
    }

    // fetch
    // Get a reference to a MyNFT from an account's Collection, if available.
    // If an account does not have a MyNFT.Collection, panic.
    // If it has a collection but does not contain the itemID, return nil.
    // If it has a collection and that collection contains the itemID, return a reference to that.
    //
    pub fun fetch(_ from: Address, itemID: UInt64): &MyNFT.NFT? {
        let collection = getAccount(from)
            .getCapability(MyNFT.CollectionPublicPath)!
            .borrow<&MyNFT.Collection{MyNFT.MyNFTCollectionPublic}>()
            ?? panic("Couldn't get collection")
        // We trust MyNFT.Collection.borowMyNFT to get the correct itemID
        // (it checks it before returning it).
        return collection.borrowMyNFT(id: itemID)
    }


    // initializer
    //
    init() {
        // set rarity price mapping
        self.itemRarityPriceMap = {
            Rarity.epic: 125.0,
            Rarity.rare: 25.0,
            Rarity.common: 5.0,
        }

        self.images = {
            Kind.fishbowl: {
                Rarity.common: "bafybeibuqzhuoj6ychlckjn6cgfb5zfurggs2x7pvvzjtdcmvizu2fg6ga",
                Rarity.rare: "bafybeihbminj62owneu3fjhtqm7ghs7q2rastna6srqtysqmjcsicmn7oa",
                Rarity.epic: "bafybeiaoja3gyoot4f5yxs4b7tucgaoj3kutu7sxupacddxeibod5hkw7m"
            },
            Kind.fishhat: {
                Rarity.common: "bafybeigu4ihzm7ujgpjfn24zut6ldrn7buzwqem27ncqupdovm3uv4h4oy",
                Rarity.rare: "bafybeih6eaczohx3ibv22bh2fsdalc46qaqty6qapums6zhelxet2gfc24",
                Rarity.epic: "bafybeifbhcez3v5dj5qgndrx73twqleajz7r2mog4exd7abs3aof7w3hhe"
            },
            Kind.milkshake: {
                Rarity.common: "bafybeialhf5ga6owaygebp6xt4vdybc7aowatrscwlwmxd444fvwyhcskq",
                Rarity.rare: "bafybeihjy4rcbvnw6bcz3zbirq5u454aagnyzjhlrffgkc25wgdcw4csoe",
                Rarity.epic: "bafybeidbua4rigbcpwutpkqvd7spppvxemwn6o2ifhq6xam4sqlngzrfiq"
            },
            Kind.tuktuk: {
                Rarity.common: "bafybeidjalsqnhj2jnisxucv6chlrfwtcrqyu2n6lpx3zpuuv2o3d3nwce",
                Rarity.rare: "bafybeiaeixpd4htnngycs7ebktdt6crztvhyiu2js4nwvuot35gzvszchi",
                Rarity.epic: "bafybeihfcumxiobjullha23ov77wgd5cv5uqrebkik6y33ctr5tkt4eh2e"
            },
            Kind.skateboard: {
                Rarity.common: "bafybeic55lpwfvucmgibbvaury3rpeoxmcgyqra3vdhjwp74wqzj6oqvpq",
                Rarity.rare: "bafybeic55lpwfvucmgibbvaury3rpeoxmcgyqra3vdhjwp74wqzj6oqvpq",
                Rarity.epic: "bafybeiepqu75oknv2vertl5nbq7gqyac5tbpekqcfy73lyk2rcjgz7irpu"
            }
        }

        // Initialize the total supply
        self.totalSupply = 0

        // Set our named paths
        self.CollectionStoragePath = /storage/MyNFTCollectionV1
        self.CollectionPublicPath = /public/MyNFTCollectionV1
        self.MinterStoragePath = /storage/MyNFTMinterV1

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // Create a public capability for the collection
        self.account.link<&MyNFT.Collection{NonFungibleToken.CollectionPublic, MyNFT.MyNFTCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }



}