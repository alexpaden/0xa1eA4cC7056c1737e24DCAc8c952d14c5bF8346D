const ReputationServiceMachine = artifacts.require("ReputationServiceMachine");
const truffleAssert = require('truffle-assertions');

contract("Security and Validations Tests", (accounts) => {
  let instance;
  const owner = accounts[0];
  const reputationFee = web3.utils.toWei("0.01", "ether");

  beforeEach(async () => {
    instance = await ReputationServiceMachine.new({ from: owner });
  });

  it("should revert for insufficient funds", async () => {
    const reputations = [
      [accounts[1], 1, "positive", "Good service"]
    ];
    await truffleAssert.reverts(
      instance.setReputationBatch(reputations, { from: owner, value: reputationFee * (reputations.length - 1) })
    );
  });

  it("should revert if payment to the receiver failed", async () => {
    // Assuming a scenario that causes payment to the receiver to fail
  });

  it("should revert if reputation not found", async () => {
    await truffleAssert.reverts(
      instance.deleteReputation(accounts[1], { from: owner })
    );
  });

  it("should revert if tag length too long", async () => {
    await truffleAssert.reverts(
      instance.setReputation(accounts[1], 1, "This tag is way too long and should exceed 32 characters", "Good service", { from: owner, value: reputationFee })
    );
  });

  it("should revert if comment length too long", async () => {
    await truffleAssert.reverts(
      instance.setReputation(accounts[1], 1, "positive", "This comment is too long".repeat(20), { from: owner, value: reputationFee })
    );
  });

  it("should revert if max reputation must be greater than zero", async () => {
    await truffleAssert.reverts(
      instance.setMaxReputation(0, { from: owner })
    );
  });

  it("should revert if owner equity cannot exceed 100%", async () => {
    await truffleAssert.reverts(
      instance.setOperatorEquity(101, { from: owner })
    );
  });

  it("should revert if no revenue available", async () => {
    const amountToWithdraw = web3.utils.toWei("0.01", "ether"); // Specifying an amount to withdraw
  
    // Attempting to withdraw without any revenue available should revert
    await truffleAssert.reverts(
      instance.withdrawOperatorRevenue(amountToWithdraw, { from: owner })
    );
  });
  
});
