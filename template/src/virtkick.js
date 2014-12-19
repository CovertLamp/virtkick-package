
var path = require('path');
var mkdirp = require('mkdirp');

var yargs = require('yargs');
var async = require('async');
var extend = require('extend');

process.setMaxListeners(100);

var env = process.env;
var argv = yargs
.alias('h', 'help')
.describe('h', 'show help')
.alias('d', 'development')
.describe('d', 'run in development mode')
.argv;

env.PORT = env.PORT || 3000;
var railsPort = env.RAILS_PORT = env.RAILS_PORT || 3001;

if(argv.h || argv.help) {
  return yargs.showHelp();
}
if(argv.d) {
  env.RAILS_ENV = 'debug';
} else {
  env.RAILS_ENV = 'production';
}


function sha512(file, cb) {
  var stream = fs.createReadStream(file);
  var algo = 'sha512';
  var shasum = crypto.createHash(algo);
  stream.on('data', function(data) {
    shasum.update(data);
  });
  stream.on('error', cb);
  stream.on('end', function() {
    cb(null, shasum.digest('hash'))
  });
}

function checkScript(cb) {
  var output = child_process.spawn('script', ['--help']);
  var allData = "";
  output.stdout.on('data', function(data) {
    allData += data.toString('utf8');
  });
  output.stderr.on('data', function(data) {
    allData += data.toString('utf8');
  });
  output.once('exit', function() {
    setTimeout(function() {
      allData.split(/\n/).forEach(function(line) {
        if(line.match(/-e/) && line.match(/--return/))
          workingScriptCommand = true;
      });;
      cb();
    }, 0);
  });
  output.once('error', function() {
    cb();
  });
}

function spawn(cwd, command, options) {
  chSpawn = child_process.spawn;

  command = command.replace('./bin/spring ', '');

  var proc;

  if(workingScriptCommand) {
    proc =
      chSpawn('script', ['/dev/null', '-e', '-q', '-c', command], extend({}, {
      env: env,
      cwd: cwd
    }, options));
  } else {
    proc = chSpawn('bash', ['-c', command], extend({}, {
      env: env,
      cwd: cwd
    }, options));
  }
  var exitHandler = function() {
    proc.kill('SIGKILL');
  };
  proc.once('exit', function() {
    process.removeListener('exit', exitHandler);
  });
  process.on('exit', exitHandler);
  ['SIGINT', 'SIGTERM', 'SIGHUP'].forEach(function(signal) {
    process.once(signal, function() {
      exitHandler();
      process.exit();
    });
  });
  return proc;
}

function spawnAsVirtkick(cmd) {
  return spawn("./", "ssh -t -t -p " + (process.env.SSH_PORT || 22) +  " -o \"StrictHostKeyChecking no\" virtkick@localhost " + cmd);
}

function runAsVirtkick(cmd, cb) {
  var proc = spawnAsVirtkick(cmd);
  var output = "";
  proc.stdout.on('data', function(data) {
    output += data.toString('utf8');
  });
  proc.stderr.on('data', function(data) {
    output += data.toString('utf8');
  });
  proc.on('exit', function(code) {
    cb(code, output);
  });

}

function bindOutput(proc, label, exitCb) {
  proc.stdout.pipe(split()).on('data', function(line) { if(line.length) process.stdout.write('['+label+'] ' + line + '\n') });
  proc.stderr.pipe(split()).on('data', function(line) { if(line.length) process.stderr.write('['+label+'] ' + line + '\n') });
  proc.on('error', forceExit);
  if(exitCb) {
    proc.on('exit', function(code) {
      console.log("Process", label, "exit:", code);
      exitCb(code);
    });
  }
}

function forceExit(code) {
  process.emit('exit');
  process.exit(code);
}

require('virtkick-proxy');

var tasks1 = [];
var tasks2 = [];
var serialTasks = [[checkScript], tasks1, tasks2];

var child_process = require('child_process');
var split = require('split');
var yaml = require('js-yaml');
var fs = require('fs');


var BASE_DIR = env.BASE_DIR || path.join(__dirname, '..');
var webappDir = env.WEBAPP_DIR || path.join(BASE_DIR, 'webapp');
var backendDir = env.BACKEND_DIR || path.join(BASE_DIR, 'backend');

function runEverything() {

  var rails = spawn(webappDir, './virtkick-webapp -p ' + railsPort);

  bindOutput(rails, 'rails', forceExit);


  var workerN = 0;
  function createWorker() {
    var worker = spawn(webappDir, './virtkick-work');
    bindOutput(worker, 'work' + workerN, forceExit);
    workerN += 1;
    return worker;
  }

  var workerCount = env.WORKER_COUNT || 2;
  workerCount = Math.min(require('os').cpus().length, Math.max(workerCount, 1));

  for(var i = 0;i < workerCount;++i) {
    createWorker();
  }


  var backend = spawn(backendDir, './virtkick-backend');
  bindOutput(backend, 'virtm', forceExit);
}


async.eachSeries(serialTasks, function(tasks, cb) {
  async.parallel(tasks, cb);
}, function(err) {
  if(err) {
    return console.log("One of required tasks has failed")
  }
  runEverything();
  if(!process.env.NO_DOWNLOAD) {
    setTimeout(function() {
      downloadIsos();
    }, 5000);
  }
});


function downloadIsos() {
  if(fs.existsSync(path.join(__dirname, ".isos-done"))) {
    console.log("All isos are downloaded, delete .isos-done to redo")
    return;
  }
  console.log("Starting download of ISO files")

  var isos = yaml.safeLoad(fs.readFileSync(path.join(webappDir, 'lib/app/app/models/plans/iso_images.yml')), {});

  async.eachLimit(isos, 4, function(iso, cb) {
    if(!iso.mirrors) {
      console.log("Iso", iso.name, "does not have mirrors");
      return cb();
    }

    console.log('[aria2c:' +iso.long_name+'] Starting download of iso: '+ iso.file);


    var aria2c = spawnAsVirtkick("~virtkick/bin/aria2c -V --check-certificate=false --seed-time=0 --save-session-interval=5 --allow-overwrite=true --follow-metalink=mem -q -c -d iso " + iso.mirrors.map(function(url) {return "'" + url + "'";}).join(" "));
    bindOutput(aria2c, 'aria2c:' +iso.long_name, function(code) {
      if(code) { 
        console.log(iso);
        return cb(code);
      }

      if(iso.sha512) {
        runAsVirtkick('sha512sum "iso/' + iso.file + '"', function(code, output) {
          var m = output.match(/^([0-9a-f]+)/);
          if(m && m[1] === iso.sha512) {
            return cb(code);
          }
          cb(code || new Error('sha512 of "iso/'+iso.file+'" does not match: expecting("'+iso.sha512+'") got("'+(m?(m[1]):null)+'") - output: ' + output));
        });
      } else {
        return cb(code);
      }

    });

  }, function(err) {
    if(err) {
      console.log("Not all isos could have been downloaded, will retry on next start", err);
      return;
    }
    console.log("All isos downloaded");
    fs.writeFileSync(path.join(__dirname, ".isos-done"), "DONE");
  });
}