const ReputationServiceMachine = artifacts.require("ReputationServiceMachine");
const truffleAssert = require('truffle-assertions');

contract("Reputation Management Tests", (accounts) => {
  let instance;
  const owner = accounts[0];
  const reputationFee = web3.utils.toWei("0.01", "ether");

  beforeEach(async () => {
    instance = await ReputationServiceMachine.new({ from: owner });
  });

  it("should set reputations in batch", async () => {
    const reputations = [
      { receiver: accounts[1], reputation: 1, tag: "positive", comment: "Good service" },
      { receiver: accounts[2], reputation: 1, tag: "positive", comment: "Excellent service" }
    ];
    await instance.setReputationBatch(reputations, { from: owner, value: reputationFee * reputations.length });

    for (let i = 0; i < reputations.length; i++) {
      const result = await instance.getReputationData(owner, reputations[i].receiver);
      assert.equal(result.reputation.toString(), reputations[i].reputation.toString(), `Reputation for receiver ${reputations[i].receiver} was not set correctly`);
    }
  });

  it("should delete reputations in batch", async () => {
    const receiversToDelete = [accounts[1], accounts[2]];
    // Set reputations first to make sure they exist
    for (const receiver of receiversToDelete) {
      await instance.setReputation(receiver, 1, "positive", "Good service", { from: owner, value: reputationFee });
    }
    await instance.deleteReputationBatch(receiversToDelete, { from: owner });

    for (const receiver of receiversToDelete) {
      const result = await instance.getReputationData(owner, receiver);
      assert.equal(result.reputation.toString(), "0", `Reputation for receiver ${receiver} was not deleted`);
    }
  });

  it("should revert for setting reputations in batch with insufficient funds", async () => {
    const reputations = [
      [accounts[2], 1, "positive", "Good service"],
      [accounts[3], 1, "positive", "Good service"]
    ];
    await truffleAssert.reverts(
      instance.setReputationBatch(reputations, { from: owner, value: reputationFee * (reputations.length - 1) })
    );
  });

  it("should set a single reputation", async () => {
    await instance.setReputation(accounts[1], 1, "positive", "Good service", { from: owner, value: reputationFee });
    const result = await instance.getReputationData(owner, accounts[1]);
    assert.equal(result.reputation.toString(), "1");
  });

  it("should delete a single reputation", async () => {
    await instance.setReputation(accounts[1], 1, "positive", "Good service", { from: owner, value: reputationFee });
    await instance.deleteReputation(accounts[1], { from: owner });
    const result = await instance.getReputationData(owner, accounts[1]);
    assert.equal(result.reputation.toString(), "0", "Reputation was not deleted");
  });

  it("should get reputation data and comment matching", async () => {
    await instance.setReputation(accounts[1], 1, "positive", "Good service", { from: owner, value: reputationFee });
    const result = await instance.getReputationData(owner, accounts[1]);
    assert.equal(result.reputation.toString(), "1");
    assert.equal(result.tag, "positive");
    assert.isTrue(await instance.isCommentMatchHash(owner, accounts[1], "Good service"));
  });

  it("should manage given and received reputations", async () => {
    await instance.setReputation(accounts[1], 1, "positive", "Good service", { from: owner, value: reputationFee });
    assert.deepEqual(await instance.getAddressesGivenReputationTo(owner), [accounts[1]]);
    assert.deepEqual(await instance.getAddressesReceivedReputationFrom(accounts[1]), [owner]);
  });

  it("should set a reputation with a negative value", async () => {
    await instance.setReputation(accounts[1], -1, "negative", "Bad service", { from: owner, value: reputationFee });
    const result = await instance.getReputationData(owner, accounts[1]);
    assert.equal(result.reputation.toString(), "-1");
  });
  
  it("should set and delete reputation with maximum comment length", async () => {
    const maxComment = "A".repeat(instance.maxCommentBytes);
    await instance.setReputation(accounts[1], 1, "positive", maxComment, { from: owner, value: reputationFee });
    const result = await instance.getReputationData(owner, accounts[1]);
    assert.equal(result.reputation.toString(), "1");
    await instance.deleteReputation(accounts[1], { from: owner });
    const deletedResult = await instance.getReputationData(owner, accounts[1]);
    assert.equal(deletedResult.reputation.toString(), "0");
  });
  
  it("should set reputations with zero value", async () => {
    await instance.setReputation(accounts[1], 0, "neutral", "Neutral service", { from: owner, value: reputationFee });
    const result = await instance.getReputationData(owner, accounts[1]);
    assert.equal(result.reputation.toString(), "0");
  });
  
  it("should set multiple reputations for the same receiver by the same sender", async () => {
    await instance.setReputation(accounts[1], 1, "positive", "Good service", { from: owner, value: reputationFee });
    await instance.setReputation(accounts[1], -1, "negative", "Bad service", { from: owner, value: reputationFee });
    const result = await instance.getReputationData(owner, accounts[1]);
    assert.equal(result.reputation.toString(), "-1"); // The latest reputation should overwrite the previous one
  });
  
});
