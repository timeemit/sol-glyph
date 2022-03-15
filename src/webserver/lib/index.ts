import ReactDOM from 'react-dom';
import React from 'react';
import Root from './Root.tsx';

const el = document.createElement('div');

ReactDOM.render((<Root />), el);

document.body.appendChild(el);

