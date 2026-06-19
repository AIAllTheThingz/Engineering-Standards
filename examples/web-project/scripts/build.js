const fs=require('fs'); fs.mkdirSync('dist',{recursive:true}); fs.copyFileSync('src/app.js','dist/app.js'); console.log('build passed');
