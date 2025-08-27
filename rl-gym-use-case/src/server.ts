import fastify from 'fastify';
import { DataProcessingJob } from './controllers/dataProcessingJob';
import { TypeBoxTypeProvider } from '@fastify/type-provider-typebox';
import { Type } from '@sinclair/typebox';
import fastifyMetrics from 'fastify-metrics';

const server = fastify({
  logger: true,
}).withTypeProvider<TypeBoxTypeProvider>();
// Register metrics plugin
server.register(fastifyMetrics, {
  endpoint: '/metrics',
  defaultMetrics: {
    enabled: true,
    prefix: 'app_',
    gcDurationBuckets: [0.001, 0.01, 0.1, 1, 2, 5],
    labels: {
      app: 'rl-gym-sample-app'
    }
  },
  routeMetrics: {
    enabled: true,
    registeredRoutesOnly: true,
    groupStatusCodes: true,
    routeBlacklist: ['/metrics', '/health', '/api/v1/query'],
    invalidRouteGroup: 'unmatched'
  }
});

server.get('/health', {
  schema: {
    response: {
      200: Type.Object({
        status: Type.String(),
      }),
    },
  },
}, async () => {
  return { status: 'ok' };
});

export async function startServer(port: number = 3000): Promise<void> {
  try {
    await server.listen({ port, host: '0.0.0.0' });
    DataProcessingJob.startJob();
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }
}


export { server };
