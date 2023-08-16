// const ReputationServiceMachine = artifacts.require("ReputationServiceMachine");
// const truffleAssert = require('truffle-assertions');

// contract("ReputationServiceMachine", (accounts) => {
//   let instance;
//   const owner = accounts[0];
//   const reputationFee = web3.utils.toWei("0.01", "ether"); // Declared only once

//   beforeEach(async () => {
//     instance = await ReputationServiceMachine.new({ from: owner });
//   });

//   it("should set reputations in batch", async () => {
//     const reputations = [
//       [accounts[2], 1, "positive", "Good service"],
//       [accounts[3], 1, "positive", "Good service"]
//     ];
//     await instance.setReputationBatch(reputations, { from: owner, value: reputationFee * reputations.length });
  
//     for (let i = 0; i < reputations.length; i++) {
//       const result = await instance.getReputationData(owner, reputations[i][0]);
//       console.log(result);
  
//       const reputation = result.reputation; // Accessing the reputation property directly
//       assert.equal(reputation.toString(), reputations[i][1].toString(), `Reputation for receiver ${reputations[i][0]} was not set correctly`);
//     }
//   });
  
//   it("should delete reputations in batch", async () => {
//     const receiversToDelete = [accounts[2], accounts[3]];
//     // Set reputations first to make sure they exist
//     for (const receiver of receiversToDelete) {
//       await instance.setReputation(receiver, 1, "positive", "Good service", { from: owner, value: reputationFee });
//     }
//     await instance.deleteReputationBatch(receiversToDelete, { from: owner });
  
//     for (const receiver of receiversToDelete) {
//       const result = await instance.getReputationData(owner, receiver);
//       assert.equal(result.reputation.toString(), "0", `Reputation for receiver ${receiver} was not deleted`);
//     }
//   });
  
//   it("should revert for setting reputations in batch with insufficient funds", async () => {
//     const reputations = [
//       [accounts[2], 1, "positive", "Good service"],
//       [accounts[3], 1, "positive", "Good service"]
//     ];
//     await truffleAssert.reverts(
//       instance.setReputationBatch(reputations, { from: owner, value: reputationFee * (reputations.length - 1) })
//     );
//   });
  


// });
