const fs = require('fs');
let code = fs.readFileSync('server.js', 'utf8');

const startIdx = code.indexOf('async function runVastuAnalysis');
const endIdx = code.indexOf('// ─── Step 6: Cost Estimation', startIdx);
const funcCode = code.substring(startIdx, endIdx);

eval(funcCode);

const samplePlan = {
  project: { width: 40, height: 40 },
  rooms: [
    { name: 'Kitchen', x: 25, y: 25, width: 10, height: 10 }, // Bottom-Right cell
    { name: 'Master Bedroom', x: 5, y: 25, width: 10, height: 10 }, // Bottom-Left cell
    { name: 'Pooja Room', x: 25, y: 5, width: 10, height: 10 }, // Top-Right cell
    { name: 'Bathroom', x: 5, y: 5, width: 10, height: 10 }, // Top-Left cell
  ]
};

const directions = ['North', 'North-East', 'East', 'South-East', 'South', 'South-West', 'West', 'North-West'];

async function testAllDirections() {
  console.log('=== VASTU 8-DIRECTION VERIFICATION TEST ===\n');
  for (const dir of directions) {
    const res = await runVastuAnalysis(samplePlan, 'Tamil', dir);
    console.log(`--- Direction: ${dir} (Returned: ${res.orientation}) ---`);
    console.log(`Score: ${res.score} | Grade: ${res.grade}`);
    console.log(`Kitchen: ${res.kitchen}`);
    console.log(`Master Bedroom: ${res.masterBedroom}`);
    console.log(`Pooja Room: ${res.poojaRoom}`);
    console.log(`Bathroom: ${res.bathroom}\n`);
  }
}

testAllDirections().catch(console.error);

