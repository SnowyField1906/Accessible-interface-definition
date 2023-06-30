---
status: draft 
flip: NNN (set to PR number)
authors: Huu Thuan Nguyen (nguyenhuuthuan25112003@gmail.com) 
sponsor: AN Expert (core-contributor@example.org)
updated: YYYY-MM-DD 
---

# FLIP NNN: Accessible Interface Definition

## Objective

> What are we doing and why? What problem will this solve? What are the goals and non-goals? This is your executive summary; keep it short, elaborate below.

This FLIP proposes to allow functions to define which contracts are able to call them based on the interfaces those contracts inherited.

This makes it easier for developers to build huge project with multiple parallel smart contracts along with complex access control rules.

## Motivation

> Why is this a valuable problem to solve? What background information is needed to show how this design addresses the problem?
> Which users are affected by the problem? Why is it a problem? What data supports this? What related work exists?

Flow made the bold move of removing `msg.sender` and replacing it with the Capability system defined by Resource. This seems to work very effectively and brings many benefits to small projects, but that efficiency is inversely proportional to the size and complexity of the project. While `msg.sender` proved to be much more efficient in these case.

Let's come up with a specific example below:

Supposes that the `Vault` contract has a function called `Vault.swap()` which should be called by the `Core` contract or `Router` contracts only. This is what we can do with the current Flow:

```cadence
access(all) contract Vault {
    access(all) resource Admin {
        access(all) fun swap(from: @FungibleToken.Vault): @FungibleToken.Vault {
            return <- Vault._swap(from: <- from)
        }
    }
    
    access(self) fun _swap(from: @FungibleToken.Vault): @FungibleToken.Vault {
        // some implementation
    }

    access(account) fun createAdmin(): @Admin {
        return <- create Vault.Admin()
    }
}
```

Way 1: Save the `Admin` Resource to the `Router` deployer account.

```cadence
access(all) contract Router {
    access(all) fun swap(from: @FungibleToken.Vault): @FungibleToken.Vault {
        return self.account.borrow<&Vault.Admin>(from: /storage/VaultAdmin)!.swap(from: <- from)
    }
}
```

Way 2: Save the `Admin` Capability to the `Router` deployer account.

```cadence
access(all) contract Router {
    let vaultAdmin: Capability<&Vault.Admin>

    access(all) fun swap(from: @FungibleToken.Vault): @FungibleToken.Vault {
        return self.vaultAdmin.swap(from: <- from)
    }

    init(vaultAdmin: Capability<&Vault.Admin>) {
        self.vaultAdmin = vaultAdmin
    }
}
```

In any way, we all have to operate with `Admin` resource, this leads to the following problems:

- The `Admin` resource definition makes the amount of code bigger, harder to maintain and update.
- Every time we want to add a new `Router` contract, we have to operate with Vault deployer account. This makes it less decentralized with many unnecessary steps.
- What if the project becomes bigger with multiple contracts and it needs more complex access control rules? We have to create more resources and more code to handle them.

## User Benefit

> How will users (or other contributors) benefit from this work? What would be the headline in the release notes or blog post?

This proposal is aimed at making contracts more decentralized, independent of the deployer account. This will be easier to manage and friendly to high complexity projects.

## Design Proposal

> This is the meat of the document where you explain your proposal. If you have multiple alternatives, be sure to use sub-sections for better separation of the idea, and list pros/cons to each approach. If there are alternatives that you have eliminated, you should also list those here, and explain why you believe your chosen approach is superior.
> Make sure you’ve thought through and addressed the following sections. If a  section is not relevant to your specific proposal, please explain why, e.g.  your FLIP addresses a convention or process, not an API.

### Declaration keywords

#### `define` keyword

Example:

```cadence
define ContractAlias from ContractInterface {
    // in this scope, we can access to the caller contract by `ContractAlias`.
    // which will be clear in the next sections.
}
```

#### `access` keyword improvements

After declare a definition, we can use `access` keyword to define which interfaces are able to call the function.
Note that the `access(ContractX)` has wider scope than `access(self)`, which means that it also can be called in the parent contract.

```cadence
access(ContractX) fun foo() { }

self.foo() // ok
```

If we want to make `foo()` callable in the inner contract, we can also combine the alias with `contract` by the `|` operator (more details below).

```cadence
// FooContract.cdc
access(ContractX | contract) fun foo() { }

access(all) resource Foo() {
    access(all) fun bar() {
        FooContract.foo() // ok
    }
}
```

#### `|` and `&` operator

As mentioned above, we can combine more than one interface by the `|` operator. This is useful when we want to make a function callable in multiple contracts.

```cadence
// FooContract.cdc
access(ContractX | ContractY | ContractZ) fun foo() { }

// BarContract.cdc
access(all) contract BarContract: IContractY, IContractZ {
    FooContract.foo() // ok
}
```

This also works with the `&` operator, which means that the function can be called by the contracts that implement all of the interfaces.

```cadence
// FooContract.cdc
access(ContractX & ContractY & ContractZ) fun foo() { }

// BarContract.cdc
access(all) contract BarContract: IContractY, IContractZ {
    FooContract.foo() // inaccessible
}

// SuperBarContract.cdc
access(all) contract SuperBarContract: IContractX, IContractY, IContractZ {
    FooContract.foo() // ok
}
```

### Drawbacks

>Why should this *not* be done? What negative impact does it have? 

### Alternatives Considered

* Make sure to discuss the relative merits of alternatives to your proposal.

### Performance Implications

* Do you expect any (speed / memory)? How will you confirm?
* There should be microbenchmarks. Are there?
* There should be end-to-end tests and benchmarks. If there are not 
(since this is still a design), how will you track that these will be created?

### Dependencies

* Dependencies: does this proposal add any new dependencies to Flow?
* Dependent projects: are there other areas of Flow or things that use Flow 
(Access API, Wallets, SDKs, etc.) that this affects? 
How have you identified these dependencies and are you sure they are complete? 
If there are dependencies, how are you managing those changes?

### Engineering Impact

* Do you expect changes to binary size / build time / test times?
* Who will maintain this code? Is this code in its own buildable unit? 
Can this code be tested in its own? 
Is visibility suitably restricted to only a small API surface for others to use?

### Best Practices

* Does this proposal change best practices for some aspect of using/developing Flow? 
How will these changes be communicated/enforced?

### Tutorials and Examples

* If design changes existing API or creates new ones, the design owner should create 
end-to-end examples (ideally, a tutorial) which reflects how new feature will be used. 
Some things to consider related to the tutorial:
    - It should show the usage of the new feature in an end to end example 
    (i.e. from the browser to the execution node). 
    Many new features have unexpected effects in parts far away from the place of 
    change that can be found by running through an end-to-end example.
    - This should be written as if it is documentation of the new feature, 
    i.e., consumable by a user, not a Flow contributor. 
    - The code does not need to work (since the feature is not implemented yet) 
    but the expectation is that the code does work before the feature can be merged. 

### Compatibility

* Does the design conform to the backwards & forwards compatibility [requirements](../docs/compatibility.md)?
* How will this proposal interact with other parts of the Flow Ecosystem?
    - How will it work with FCL?
    - How will it work with the Emulator?
    - How will it work with existing Flow SDKs?

### User Impact

* What are the user-facing changes? How will this feature be rolled out?

## Related Issues

What related issues do you consider out of scope for this proposal, 
but could be addressed independently in the future?

## Prior Art

Does the proposed idea/feature exist in other systems and 
what experience has their community had?

This section is intended to encourage you as an author to think about the 
lessons learned from other projects and provide readers of the proposal 
with a fuller picture.

It's fine if there is no prior art; your ideas are interesting regardless of 
whether or not they are based on existing work.

## Questions and Discussion Topics

Seed this with open questions you require feedback on from the FLIP process. 
What parts of the design still need to be defined?
