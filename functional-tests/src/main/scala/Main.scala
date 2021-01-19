import com.typesafe.config.ConfigFactory
import com.typesafe.config.Config
import com.vertica.spark.config.{DistributedFilesystemReadConfig, FileStoreConfig, JDBCConfig, VerticaMetadata}
import com.vertica.spark.functests.{HDFSTests, JDBCTests}
import ch.qos.logback.classic.Level

object Main extends App {
  val conf: Config = ConfigFactory.load()

  val jdbcConfig = JDBCConfig(host = conf.getString("functional-tests.host"),
                              port = conf.getInt("functional-tests.port"),
                              db = conf.getString("functional-tests.db"),
                              username = conf.getString("functional-tests.user"),
                              password = conf.getString("functional-tests.password"),
                              logLevel= if(conf.getBoolean("functional-tests.log")) Level.DEBUG else Level.OFF)

  (new JDBCTests(jdbcConfig)).execute()

  val filename = "hdfs://localhost:8020/data/testhdfs.parquet"
  val dirTestFilename = "hdfs://localhost:8020/data/dirtest/"
  new HDFSTests(
    DistributedFilesystemReadConfig(
      logLevel = if(conf.getBoolean("functional-tests.log")) Level.ERROR else Level.OFF,
      jdbcConfig,
      FileStoreConfig(filename, Level.ERROR),
      "",
      None
    ),
    DistributedFilesystemReadConfig(
      if(conf.getBoolean("functional-tests.log")) Level.ERROR else Level.OFF,
      jdbcConfig,
      FileStoreConfig(dirTestFilename, Level.ERROR),
      "",
      None
    )
  ).execute()
}
