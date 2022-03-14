import express from 'express';
import path from 'path';
import {fileURLToPath} from 'url';

const __dirname = path.dirname(__filename);
const app = express();
const port = process.env.PORT || 3000;

app.use(express.static(path.resolve(__dirname, 'dist')));

app.listen(port, () => {
  console.log(`Example app listening on port ${port}`)
});
