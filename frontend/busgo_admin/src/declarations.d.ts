/// <reference types="vite/client" />

declare module '*.jpeg' {
  const src: string;
  export default src;
}

declare module '*.png' {
  const src: string;
  export default src;
}

declare module '*.svg?raw' {
  const content: string;
  export default content;
}

declare module 'animejs' {
  const anime: any;
  export default anime;
}

declare module 'animejs/lib/anime.es.js' {
  const anime: any;
  export default anime;
}






