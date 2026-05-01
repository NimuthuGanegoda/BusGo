const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
require('dotenv').config();

// Adjust this import path to match your actual User/Driver model
const Driver = require('./src/models/Driver'); 

async function createTestDriver() {
  await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/busgo');
  
  const hashedPassword = await bcrypt.hash('test1234', 10);
  
  await Driver.create({
    name: 'Test Driver',
    email: 'driver@busgo.lk',
    password: hashedPassword,
    phone: '0771234567',
    licenseNumber: 'B1234567',
    status: 'active'
  });

  console.log('✅ Test driver created!');
  console.log('   Email:    driver@busgo.lk');
  console.log('   Password: test1234');
  mongoose.disconnect();
}

createTestDriver().catch(console.error);






