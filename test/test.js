const fs = require("fs");
const ReputationServiceMachine = artifacts.require("ReputationServiceMachine");

contract("ReputationServiceMachine - Gas Measurement", (accounts) => {
  let instance;

  beforeEach(async () => {
    instance = await ReputationServiceMachine.new();
  });

  it("should measure gas cost as the mapping increases size to 5000 reputations received", async () => {
    const sender = accounts[0];
    const receivers = accounts.slice(1, 5001); // 5000 receivers
    const filePath = "gas_costs.csv";

    // Write the CSV header
    fs.writeFileSync(filePath, "Reputation Number,Gas Used\n");

    for (let i = 0; i < receivers.length; i++) {
      try {
        const receiver = receivers[i];
        const reputation = 1;
        const comment = "Positive feedback";

        // Measure the gas cost
        const tx = await instance.setReputation(receiver, reputation, comment, {
          from: sender,
        });
        const gasUsed = tx.receipt.gasUsed;

        // Log and write the result
        console.log(`Gas used for reputation ${i + 1}: ${gasUsed}`);
        fs.appendFileSync(filePath, `${i + 1},${gasUsed}\n`);
      } catch (error) {
        console.error(`Error processing reputation ${i + 1}:`, error);
      }
    }

    console.log(`Results written to ${filePath}`);
  });
});
