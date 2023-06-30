///// Example 1
import IPlugin from "IPlugin"

define PoolPlugin from IPlugin { } // do not have conditions

access(all) contract Vault {
    access(PoolPlugin | Router) fun _swap(from: @FungibleToken.Vault): @FungibleToken.Vault;
    access(all) fun exactInput(amountIn: UFix64): UFix64;
}

access(all) contract interface IPlugin {
    access(contract) fun _swap(from: @FungibleToken.Vault): @FungibleToken.Vault {
        post {
            result.balance == Vault.exactInput(amountIn: from.balance): "You cheated!!"
        }
    }
}
access(all) contract Plugin: IPlugin {
    access(contract) fun _swap(from: @FungibleToken.Vault): @FungibleToken.Vault {
        let to: @FungibleToken = Vault._swap(from: <- from) // always valid from IPlugin

        to.withdraw(amount: to.balance / 2.0) // cheat half of the amount

        return to; // post-condition failed: You cheated!!
    }
}


///// Example 2
import IConsensus from "IConsensus"

define Consensus from IConsensus { } // do not have conditions

access(all) contract Nodes {
    access(Collection | Consensus | Execution | Verification) fun receivedTx();
}

access(all) contract interface IConsensus {
    access(all) fun validate(tx: @Transaction): @Transaction {
        pre {
            tx.collected() == true: "Send this transaction to Collection Node first"
            tx.validated() == false: "This transaction is already executed"
        }
        post {
            tx.validated() == true: "This transaction is not validated"
        }
    }
}
access(all) contract Consensus: IConsensus {
    access(all) fun validate(tx: @Transaction): @Transaction {
        Nodes.receivedTx() // always valid from IConsensus

        // ... do something to make tx.validated() == true

        return <- validatedTx
    }
}


///// Example 3
import IConsensus from "IConsensus"
import IExecution from "IExecution"

define Consensus from IConsensus { } // do not have conditions
define Execution from IExecution {
    let exeAddr: Address = Execution.account.address
    assert(Nodes.validExecutions.exists(exeAddr), message: "Execution is not valid")

    let balance: UFix64 = getAccount(Execution.account.address)
        .capabilities
        .get<&{FungibleToken.Balance}>(/public/flowTokenBalance)
        .borrow()!
    assert(balance >= Nodes.minimumStaked: "Execution is not staked enough")
}


access(all) contract Nodes {
    access(Collection | Consensus | Execution | Verification) fun receivedTx();


    access(all) let validExecutions: [Address] = [0x01]
    access(all) let MINIMUM_STAKED: UFix64 = 1250000.0

    access(Router | GOV) fun addExecution(execution: Address);
    access(Collection | Consensus | Execution | Verification) fun withdrawn();

    access(Execution) fun executed();
}

access(all) contract InvalidExecution: IExecution { // deployed at 0x02
    access(all) fun execute() {
        Nodes.executed() // assertion failed: Execution is not valid
    }
}
access(all) contract PoorExecution: IExecution { // deployed at 0x01 and had less than 1.250.000 Flow
    access(all) fun execute() {
        Nodes.executed() // assertion failed: Execution is not staked enough
    }
}
access(all) contract ValidExecution: IExecution { //deployed at 0x01 and had over 1.250.000 Flow
    access(all) fun execute() {
        Nodes.executed() // valid
    }
}


///// Example 4

define Balance from SpecialBalance { }
define Receiver from SpecialReceiver { }
define Provider from SpecialProvider { }

access(all) contract Bank {
    access(Balance) fun getInterest(): UFix64;

    access(Provider) fun withdrawAll();

    access(Balance & Receiver & Provider) fun subscribed()
}

access(all) resource interface SpecialBalance {
    access(all) fun getAvailableBalance(): UFix64;

    access(all) fun getAllPossibleBalance(): UFix64 {
        return self.getAvailableBalance() + Bank.getInterest() // always valid from Balance
    }
}
access(all) resource interface SpecialProvider {
    access(all) fun withdraw(amount: UFix64): @FungibleToken.Vault;

    access(all) fun withdrawAll(): @FungibleToken.Vault {
        Bank.withdrawAll() // always valid from Provider
        /// ... some implementation
    }
}
access(all) resource SpecialVault: Balance, Receiver, Provider {
    // some implementation

    access(all) fun subscribe() {
        Bank.subscribed() // always valid from Balance & Receiver & Provider
    }
}