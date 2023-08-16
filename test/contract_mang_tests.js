const ReputationServiceMachine = artifacts.require("ReputationServiceMachine");
const truffleAssert = require('truffle-assertions');

contract("Contract Configuration and Administration Tests", (accounts) => {
  let instance;
  const owner = accounts[0];

  beforeEach(async () => {
    instance = await ReputationServiceMachine.new({ from: owner });
  });

  it("should modify the reputation fee", async () => {
    const newFee = web3.utils.toWei("0.02", "ether");
    await instance.setReputationFee(newFee, { from: owner });
    const result = await instance.reputationFee();
    assert.equal(result.toString(), newFee);
  });

  it("should set the maximum reputation value", async () => {
    const newMaxReputation = 5;
    await instance.setMaxReputation(newMaxReputation, { from: owner });
    const result = await instance.maxReputation();
    assert.equal(result.toString(), newMaxReputation);
  });

  it("should manage operator's equity", async () => {
    const newEquity = 90;
    await instance.setOperatorEquity(newEquity, { from: owner });
    const result = await instance.operatorEquity();
    assert.equal(result.toString(), newEquity);
    await truffleAssert.reverts(instance.setOperatorEquity(101, { from: owner }));
  });

  it("should set the maximum comment bytes", async () => {
    const newMaxCommentBytes = 400;
    await instance.setMaxCommentBytes(newMaxCommentBytes, { from: owner });
    const result = await instance.maxCommentBytes();
    assert.equal(result.toString(), newMaxCommentBytes);
  });

  it("should withdraw operator revenue", async () => {
    // Setting up the revenue
    const fee = web3.utils.toWei("0.01", "ether");
    await instance.setReputation(accounts[1], 1, "positive", "Good service", { from: owner, value: fee });
  
    // Getting the initial balance
    const initialBalance = await web3.eth.getBalance(owner);
  
    // Specifying the amount to withdraw (in this case, the full fee)
    const amountToWithdraw = fee;
  
    // Withdrawing the revenue and getting the transaction receipt to calculate gas costs
    const tx = await instance.withdrawOperatorRevenue(amountToWithdraw, { from: owner });
    const txReceipt = await web3.eth.getTransactionReceipt(tx.tx);
    const gasCost = txReceipt.gasUsed * (await web3.eth.getGasPrice());
  
    // Calculating the expected final balance
    const expectedFinalBalance = BigInt(initialBalance) + BigInt(fee) - BigInt(gasCost);
  
    // Getting the actual final balance
    const finalBalance = await web3.eth.getBalance(owner);
  
    assert.equal(finalBalance.toString(), expectedFinalBalance.toString());
  });  

  it("should transfer ownership", async () => {
    const newOwner = accounts[1];
    await instance.transferOwnership(newOwner, { from: owner });
    assert.equal(await instance.owner(), newOwner);
  });

  it("should withdraw partial operator revenue", async () => {
    // Setting up the revenue
    const fee = web3.utils.toWei("0.01", "ether");
    await instance.setReputation(accounts[1], 1, "positive", "Good service", { from: owner, value: fee });
  
    // Specifying a partial amount to withdraw
    const amountToWithdraw = web3.utils.toWei("0.005", "ether");
  
    // Withdrawing the partial amount
    await instance.withdrawOperatorRevenue(amountToWithdraw, { from: owner });
  
    // Checking the remaining operator revenue
    const remainingRevenue = await instance.operatorRevenue();
    assert.equal(remainingRevenue.toString(), web3.utils.toWei("0.005", "ether"));
  });
  
  it("should withdraw operator revenue when exactly equal to the available revenue", async () => {
    // Setting up the revenue
    const fee = web3.utils.toWei("0.01", "ether");
    await instance.setReputation(accounts[1], 1, "positive", "Good service", { from: owner, value: fee });
  
    // Withdrawing the exact available revenue
    await instance.withdrawOperatorRevenue(fee, { from: owner });
  
    // Checking that the operator revenue is now zero
    const remainingRevenue = await instance.operatorRevenue();
    assert.equal(remainingRevenue.toString(), "0");
  });
  
  it("should revert if withdrawing operator revenue with a non-owner account", async () => {
    // Setting up the revenue
    const fee = web3.utils.toWei("0.01", "ether");
    await instance.setReputation(accounts[1], 1, "positive", "Good service", { from: owner, value: fee });
  
    // Attempting to withdraw revenue with a non-owner account should revert
    await truffleAssert.reverts(
      instance.withdrawOperatorRevenue(fee, { from: accounts[1] }),
      "Ownable: caller is not the owner"
    );
  });
  
});
