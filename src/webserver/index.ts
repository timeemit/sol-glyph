import express from 'express';
import * as path from 'path';
import {fileURLToPath} from 'url';

import {
    establishConnection,
    establishPayer,
    executeOnnxPipeline,
    report,
    requestAirdrop,
} from './solana';


const app = express();
const port = process.env.PORT || 3000;

app.use((req, res, next)  =>{
  // Require HTTPS.  The 'x-forwarded-proto' check is for Heroku
  if (!req.secure && req.get('x-forwarded-proto') !== 'https' && process.env.NODE_ENV !== "development") {
    return res.redirect('https://' + req.get('host') + req.url);
  }
  next();
})

app.use('/', express.static(path.resolve(__dirname, 'dist')));

app.use(express.json());

app.post('/img', async (req, res, next) => {
  // Execute ONNX
  executeOnnxPipeline(req.body.values).then(result => res.json(result)).catch(next);
});

const listen = () => {
  app.listen(port, () => {
    console.log(`Example app listening on port ${port}`)
  });
}

// Replenish funds ad-infinitum
setInterval(requestAirdrop, 60000);

// Establish connection, account, and funds to the cluster before setting up server
const connection = establishConnection().then(establishPayer).then(requestAirdrop).then(listen);
