  Contract: Contract Configuration and Administration Tests
    ✔ should modify the reputation fee (385ms)
    ✔ should set the maximum reputation value (455ms)
    ✔ should manage operator's equity (596ms)
    ✔ should set the maximum comment bytes (420ms)
    ✔ should withdraw operator revenue (5348ms)
    ✔ should transfer ownership (473ms)
    ✔ should withdraw partial operator revenue (5662ms)
    ✔ should withdraw operator revenue when exactly equal to the available revenue (6082ms)
    ✔ should revert if withdrawing operator revenue with a non-owner account (6253ms)

  Contract: Reputation Management Tests
    ✔ should set reputations in batch (10968ms)
    ✔ should delete reputations in batch (13465ms)
    ✔ should revert for setting reputations in batch with insufficient funds (80ms)
    ✔ should set a single reputation (5674ms)
    ✔ should delete a single reputation (6926ms)
    ✔ should get reputation data and comment matching (6983ms)
    ✔ should manage given and received reputations (7118ms)
    ✔ should set a reputation with a negative value (6189ms)
    ✔ should set and delete reputation with maximum comment length (8407ms)
    ✔ should set reputations with zero value (6842ms)
    ✔ should set multiple reputations for the same receiver by the same sender (11067ms)

  Contract: Security and Validations Tests
    ✔ should revert for insufficient funds (108ms)
    ✔ should revert if payment to the receiver failed
    ✔ should revert if reputation not found (155ms)
    ✔ should revert if tag length too long (93ms)
    ✔ should revert if comment length too long (139ms)
    ✔ should revert if max reputation must be greater than zero (106ms)
    ✔ should revert if owner equity cannot exceed 100% (124ms)
    ✔ should revert if no revenue available (109ms)