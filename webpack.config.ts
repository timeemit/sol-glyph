import * as path from 'path';
import * as webpack from 'webpack';

import {fileURLToPath} from 'url';


const config: webpack.Configuration = {
  entry: './src/webserver/lib/index.js',
  output: {
    filename: 'main.js',
    path: path.resolve(__dirname, 'src/webserver/dist'),
  },
};

export default config;
