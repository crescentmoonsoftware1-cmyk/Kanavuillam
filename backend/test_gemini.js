const { GoogleGenerativeAI } = require('@google/generative-ai');
const dotenv = require('dotenv');
dotenv.config();

async function test() {
  console.log('Testing Gemini API Key...');
  const key = process.env.GEMINI_API_KEY;
  if (!key) {
    console.log('No GEMINI_API_KEY found in .env');
    return;
  }
  
  const genAI = new GoogleGenerativeAI(key);
  try {
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
    const result = await model.generateContent('Say exactly: Hello World');
    console.log('SUCCESS! Response from Gemini:', result.response.text().trim());
  } catch (error) {
    console.error('ERROR:', error.message);
  }
}
test();
