const fs=require('fs'); const src=fs.readFileSync('src/app.js','utf8'); if(src.includes('innerHTML')) process.exit(1); console.log('lint passed');
