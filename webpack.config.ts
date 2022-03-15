import * as path from 'path';
import * as webpack from 'webpack';

import {fileURLToPath} from 'url';


const config: webpack.Configuration = {
  entry: './src/webserver/lib/index.ts',
  output: {
    filename: 'main.js',
    path: path.resolve(__dirname, 'src/webserver/dist'),
  },
	module: {
		rules: [
			{
				test: /\.(ts|tsx)$/,
				exclude: /(node_modules|bower_components)/,
				use: {
					loader: 'babel-loader',
					options: {
						presets: ['@babel/preset-env', '@babel/preset-typescript', '@babel/preset-react']
					}
				}
			},
		]
	},
  resolve: {
    extensions: ['.tsx', '.ts', '.js'],
  },
};

export default config;
