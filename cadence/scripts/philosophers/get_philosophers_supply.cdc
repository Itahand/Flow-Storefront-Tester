import PhilosophersNFT from "../../contracts/PhilosophersNFT.cdc"

// This scripts returns the number of Philosopher currently in existence.

pub fun main(): UInt64 {
    return PhilosophersNFT.totalSupply
}
