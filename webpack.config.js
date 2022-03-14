import path from 'path';
import {fileURLToPath} from 'url';


const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);


export default {
  entry: './src/webserver/lib/index.js',
  output: {
    filename: 'main.js',
    path: path.resolve(__dirname, 'src/webserver/dist'),
  },
};
