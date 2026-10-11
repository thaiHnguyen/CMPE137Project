import 'package:dotenv/dotenv.dart';
import 'package:mysql_client/mysql_client.dart';

/// Environment variables loaded from server/.env.
final env = DotEnv(includePlatformEnvironment: true)..load();

/// Shared MySQL connection pool used by all routes.
final db = MySQLConnectionPool(
  host: env['DB_HOST'] ?? 'localhost',
  port: int.parse(env['DB_PORT'] ?? '3306'),
  userName: env['DB_USER'] ?? '',
  password: env['DB_PASSWORD'] ?? '',
  databaseName: env['DB_NAME'],
  maxConnections: 10,
);
