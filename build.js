#!/usr/bin/env /usr/local/bin/node
var fs = require('fs'),
    path = require('path'),
    UglifyJS = require('uglify-js'),
    files = [
        'debug',
        'core',
        'Communicator',
        'Promise',
        'Observable',
        'Camera',
        'Connection',
        'Notification',
        'Orientation',
        'invoke/Connection',
        'Invoke',
        'Sqlite',
        'FileSystem',
        'localstorage/Collection',
        'SecureLocalStorage',
        'extra'
    ],
    content = [];


files.forEach(function(file) {
    content.push(fs.readFileSync(path.join('src', file + '.js'), 'utf8'));
});

!fs.existsSync('out') && fs.mkdirSync('out');
fs.writeFileSync('out/space.js', content.join('\n'));

result = UglifyJS.minify('out/space.js', {
    compress: {
        global_defs: {
            DEBUG: false
        }
    }
});

fs.writeFileSync('out/space.min.js', result.code);
