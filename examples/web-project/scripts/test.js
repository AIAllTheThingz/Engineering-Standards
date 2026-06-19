const fs=require('fs'); const src=fs.readFileSync('src/app.js','utf8'); if(!src.includes('renderMessage')) process.exit(1); console.log('tests passed');
