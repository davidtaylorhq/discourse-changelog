import Application from './app/app';
import environment from './app/config/environment';

if(!window.FastBoot){
  console.log("BOOTING")
  Application.create(environment.APP);
}

