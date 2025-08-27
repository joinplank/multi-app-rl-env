import { FastifyRequest } from 'fastify';
import { Registry } from 'prom-client';

declare module 'fastify' {
  interface FastifyRequest {
    metrics: {
      startTime: [number, number];
    };
  }
}

declare module 'fastify-metrics' {
  export interface MetricsPluginOptions {
    endpoint: string;
    registry?: Registry;
  }
}