import express from 'express';
import * as path from 'path';
import {fileURLToPath} from 'url';

import {
    establishConnection,
    establishPayer,
    executeOnnxPipeline,
    report,
} from './solana';


const app = express();
const port = process.env.PORT || 3000;

app.use('/', express.static(path.resolve(__dirname, 'dist')));

app.use(express.json());

app.post('/img', async (req, res, next) => {
  // Determine who pays for the fees
  const payer = connection.then(() => establishPayer());

  // Execute ONNX
  const output = payer.then(() => executeOnnxPipeline(req.body.values));
  output.then(result => res.json(result)).catch(next);
});

const listen = () => {
  app.listen(port, () => {
    console.log(`Example app listening on port ${port}`)
  });
}

// Establish connection and account to the cluster before setting up server
const connection = establishConnection().then(listen);
