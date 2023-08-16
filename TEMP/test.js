// const fs = require("fs");
// const ReputationServiceMachine = artifacts.require("ReputationServiceMachine");

// contract("ReputationServiceMachine - Gas Measurement", (accounts) => {
//   let instance;
//   const reputationFee = web3.utils.toWei("0.01", "ether"); // 0.01 Ether

//   beforeEach(async () => {
//     instance = await ReputationServiceMachine.new();
//     // Optionally, you can set the reputation fee in the contract if it has a setter method
//     // await instance.setReputationFee(reputationFee, { from: accounts[0] });
//   });

//   it("should measure gas cost as the mapping increases size to 5000 reputations received", async () => {
//     const sender = accounts[0];
//     const receivers = accounts.slice(1, 5); // 5000 receivers
//     const filePath = "gas_costs.csv";

//     // Write the CSV header
//     fs.writeFileSync(filePath, "Reputation Number,Gas Used\n");

//     for (let i = 0; i < receivers.length; i++) {
//       try {
//         const receiver = receivers[i];
//         const reputation = 1;
//         const comment = "Positive feedback";
//         const tag = ""; // Add tag if required

//         // Measure the gas cost
//         const tx = await instance.setReputation(receiver, reputation, tag, comment, {
//           from: sender,
//           value: reputationFee, // Paying the reputation fee
//         });
//         const gasUsed = tx.receipt.gasUsed;

//         // Log and write the result
//         console.log(`Gas used for reputation ${i + 1}: ${gasUsed}`);
//         fs.appendFileSync(filePath, `${i + 1},${gasUsed}\n`);
//       } catch (error) {
//         console.error(`Error processing reputation ${i + 1}:`, error);
//       }
//     }

//     console.log(`Results written to ${filePath}`);
//   });
// });
