import { mergeConfig, type UserConfig } from 'vite';
 
 export default (config: UserConfig) => {
   // Important: always return the modified config
   return mergeConfig(config, {
     resolve: {
       alias: {
         '@': '/src',
       },
     },
     server: {
       host: true, // allows access from all IPs (like ALB or external devices)
       cors: {
         origin: '*', // <-- allow ALL domains
         methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
         allowedHeaders: ['Content-Type', 'Authorization'],
       },
       proxy: {
        allowedHosts: ['*']
      }
     },
   });
 };