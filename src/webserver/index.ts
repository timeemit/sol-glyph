import express from 'express';
import * as path from 'path';
import {fileURLToPath} from 'url';

const app = express();
const port = process.env.PORT || 3000;

app.use(express.static(path.resolve(__dirname, 'dist')));

app.listen(port, () => {
  console.log(`Example app listening on port ${port}`)
});
