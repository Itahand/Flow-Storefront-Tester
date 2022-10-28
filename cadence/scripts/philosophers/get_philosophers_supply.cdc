import Philosophers from "../../contracts/Philosophers.cdc"

// This scripts returns the number of Philosopher currently in existence.

pub fun main(): UInt64 {
    return Philosophers.totalSupply
}
