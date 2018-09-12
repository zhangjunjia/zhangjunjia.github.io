---
layout: post
title: HBase增量备份数据
date: '2016-05-11 21:19'
comments: true
categories: ['编程实践']  
tags: ['HBase', 'Hadoop']
---

HBase如何增量备份数据呢？

<!--more-->

## 传统的Export不支持自定义rowkey增量数据导出

导出语法：

```
hbase org.apache.hadoop.hbase.mapreduce.Export your_hbase_table_name your_hdfs_file_path
```

下面简单介绍如何实现自定义rowkey增量导出HBase数据。

<!--more-->

## 运行环境

笔者的hadoop+hbase环境如下：

$ `hadoop version`

```
Hadoop 2.6.0-cdh5.4.3
Subversion http://github.com/cloudera/hadoop -r 4cd9f51a3f1ef748d45b8d77d0f211ad44296d4b
Compiled by jenkins on 2015-06-25T02:34Z
Compiled with protoc 2.5.0
From source with checksum 4acea6ac185376e0b48b33695e88e7a7
This command was run using /opt/cloudera/parcels/CDH-5.4.3-1.cdh5.4.3.p0.6/jars/hadoop-common-2.6.0-cdh5.4.3.jar
```

$ `hbase version`

```
Java HotSpot(TM) 64-Bit Server VM warning: Using incremental CMS is deprecated and will likely be removed in a future release
16/06/04 13:13:30 INFO util.VersionInfo: HBase 1.0.0-cdh5.4.3
16/06/04 13:13:30 INFO util.VersionInfo: Source code repository file:///data/jenkins/workspace/generic-package-ubuntu64-12-04/CDH5.4.3-Packaging-HBase-2015-06-24_19-16-53/hbase-1.0.0+cdh5.4.3+159-1.cdh5.4.3.p0.9~precise revision=Unknown
16/06/04 13:13:30 INFO util.VersionInfo: Compiled by jenkins on Wed Jun 24 19:32:40 PDT 2015
16/06/04 13:13:30 INFO util.VersionInfo: From source with checksum d5809febb1e487265280a25f5c74202e
```

## 如何定制自己的Export实现自定义rowkey增量数据导出

首先，你需要找到源码org.apache.hadoop.hbase.mapreduce.Export.java，修改它为你想要的，并将其上传到具备hadoop+hbase环境的机器上；

紧接着，运行如下语句：

```bash
# 编译并打包
export HADOOP_CLASSPATH=$(hbase classpath)
hadoop com.sun.tools.javac.Main Export.java
jar cf Export.jar Export.class
# 准备好hdfs路径
su
su hdfs -c 'hdfs dfs -mkdir /backup'
su hdfs -c 'hdfs dfs -mkdir /backup/20160512'
su hdfs -c 'hdfs dfs -ls  /'
# 使用jar包
## 兼容传统Export
hadoop jar Export.jar Export group_hour /backup/20160512/group_hour
## 实现了自定义rowkey解析
hadoop jar Export.jar Export -D hbase.mapreduce.scan.row.start=1,9,2016-05-01 -D hbase.mapreduce.scan.row.stop=1,9,2015-05-02 group_hour /backup/20160512/group_hour_rowkey
```

上述命令执行成功后，就可执行`hdfs dfs -get your_hdfs_filepath your_filesystem_filepath`取得你的导出数据啦！

笔者修改后的Export.java如下：

```java
/**
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import java.io.IOException;
import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;

import com.sun.security.auth.module.UnixSystem;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.hadoop.hbase.classification.InterfaceAudience;
import org.apache.hadoop.hbase.classification.InterfaceStability;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.hbase.HBaseConfiguration;
import org.apache.hadoop.hbase.client.Result;
import org.apache.hadoop.hbase.client.Scan;
import org.apache.hadoop.hbase.filter.CompareFilter.CompareOp;
import org.apache.hadoop.hbase.filter.Filter;
import org.apache.hadoop.hbase.filter.IncompatibleFilterException;
import org.apache.hadoop.hbase.filter.PrefixFilter;
import org.apache.hadoop.hbase.filter.RegexStringComparator;
import org.apache.hadoop.hbase.filter.RowFilter;
import org.apache.hadoop.hbase.io.ImmutableBytesWritable;
import org.apache.hadoop.hbase.mapreduce.IdentityTableMapper;
import org.apache.hadoop.hbase.mapreduce.TableInputFormat;
import org.apache.hadoop.hbase.util.Bytes;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.mapreduce.lib.output.SequenceFileOutputFormat;
import org.apache.hadoop.util.GenericOptionsParser;

/**
 * Export an HBase table. Writes content to sequence files up in HDFS. Use
 * {@link Import} to read it back in again.
 */
@InterfaceAudience.Public
@InterfaceStability.Stable
public class Export {
    private static final Log LOG = LogFactory.getLog(Export.class);
    final static String NAME = "export";
    final static String RAW_SCAN = "hbase.mapreduce.include.deleted.rows";
    final static String EXPORT_BATCHING = "hbase.export.scanner.batch";
    final static DateFormat format = new SimpleDateFormat("yyyy-MM-dd");

    /**
     * Sets up the actual job.
     *
     * @param conf
     *            The current configuration.
     * @param args
     *            The command line parameters.
     * @return The newly created job.
     * @throws IOException
     *             When setting up the job fails.
     */
    public static Job createSubmittableJob(Configuration conf, String[] args)
            throws IOException {
        String tableName = args[0];
        Path outputDir = new Path(args[1]);
        Job job = new Job(conf, NAME + "_" + tableName);
        job.setJobName(NAME + "_" + tableName);
        job.setJarByClass(Export.class);
        job.setUser("hdfs");
        // Set optional scan parameters
        Scan s = getConfiguredScanForJob(conf, args);
        IdentityTableMapper.initJob(tableName, s, IdentityTableMapper.class,
                job);
        // No reducers. Just write straight to output files.
        job.setNumReduceTasks(0);
        job.setOutputFormatClass(SequenceFileOutputFormat.class);
        job.setOutputKeyClass(ImmutableBytesWritable.class);
        job.setOutputValueClass(Result.class);
        FileOutputFormat.setOutputPath(job, outputDir); // job conf doesn't
                                                        // contain the conf so
                                                        // doesn't have a
                                                        // default fs.
        return job;
    }

    private static Scan getConfiguredScanForJob(Configuration conf,
            String[] args) throws IOException {
        Scan s = new Scan();
        // Optional arguments.
        // Set Scan Versions
        int versions = args.length > 2 ? Integer.parseInt(args[2]) : 1;
        s.setMaxVersions(versions);
        // Set Scan Range
        long startTime = args.length > 3 ? Long.parseLong(args[3]) : 0L;
        long endTime = args.length > 4 ? Long.parseLong(args[4])
                : Long.MAX_VALUE;
        s.setTimeRange(startTime, endTime);
        // Set cache blocks
        s.setCacheBlocks(false);
        // set Start and Stop row
        if (conf.get(TableInputFormat.SCAN_ROW_START) != null) {
            String rowStart[] = conf.get(TableInputFormat.SCAN_ROW_START).split(",");
            Short companyID = Short.valueOf(rowStart[0]);
            Short deviceID = Short.valueOf(rowStart[1]);
            Long insertTime = 0l;
            try {
                insertTime = format.parse(rowStart[2]).getTime();
            } catch (ParseException e) {
                // ignore
            }
            s.setStartRow(Bytes.add(Bytes.toBytes(companyID),
                    Bytes.toBytes(deviceID), Bytes.toBytes(insertTime)));
        }
        if (conf.get(TableInputFormat.SCAN_ROW_STOP) != null) {
            String rowStop[] = conf.get(TableInputFormat.SCAN_ROW_STOP).split(",");
            Short companyID = Short.valueOf(rowStop[0]);
            Short deviceID = Short.valueOf(rowStop[1]);
            Long insertTime = 0l;
            try {
                insertTime = format.parse(rowStop[2]).getTime();
            } catch (ParseException e) {
                // ignore
            }
            s.setStopRow(Bytes.add(Bytes.toBytes(companyID),
                    Bytes.toBytes(deviceID), Bytes.toBytes(insertTime)));
        }
        // Set Scan Column Family
        boolean raw = Boolean.parseBoolean(conf.get(RAW_SCAN));
        if (raw) {
            s.setRaw(raw);
        }

        if (conf.get(TableInputFormat.SCAN_COLUMN_FAMILY) != null) {
            s.addFamily(Bytes.toBytes(conf
                    .get(TableInputFormat.SCAN_COLUMN_FAMILY)));
        }
        // Set RowFilter or Prefix Filter if applicable.
        Filter exportFilter = getExportFilter(args);
        if (exportFilter != null) {
            LOG.info("Setting Scan Filter for Export.");
            s.setFilter(exportFilter);
        }

        int batching = conf.getInt(EXPORT_BATCHING, -1);
        if (batching != -1) {
            try {
                s.setBatch(batching);
            } catch (IncompatibleFilterException e) {
                LOG.error("Batching could not be set", e);
            }
        }
        StringBuffer sb = new StringBuffer("versions=" + versions + ", starttime=" + startTime
                + ", endtime=" + endTime + ", keepDeletedCells=" + raw);
        if (conf.get(TableInputFormat.SCAN_ROW_START) != null) {
            sb.append(", startRow=" + conf.get(TableInputFormat.SCAN_ROW_START));
            sb.append(", stopRow=" + conf.get(TableInputFormat.SCAN_ROW_STOP));
        }
        LOG.info(sb.toString());
        return s;
    }

    private static Filter getExportFilter(String[] args) {
        Filter exportFilter = null;
        String filterCriteria = (args.length > 5) ? args[5] : null;
        if (filterCriteria == null)
            return null;
        if (filterCriteria.startsWith("^")) {
            String regexPattern = filterCriteria.substring(1,
                    filterCriteria.length());
            exportFilter = new RowFilter(CompareOp.EQUAL,
                    new RegexStringComparator(regexPattern));
        } else {
            exportFilter = new PrefixFilter(Bytes.toBytes(filterCriteria));
        }
        return exportFilter;
    }

    /*
     * @param errorMsg Error message. Can be null.
     */
    private static void usage(final String errorMsg) {
        if (errorMsg != null && errorMsg.length() > 0) {
            System.err.println("ERROR: " + errorMsg);
        }
        System.err
                .println("Usage: Export [-D <property=value>]* <tablename> <outputdir> [<versions> "
                        + "[<starttime> [<endtime>]] [^[regex pattern] or [Prefix] to filter]]\n");
        System.err
                .println("  Note: -D properties will be applied to the conf used. ");
        System.err.println("  For example: ");
        System.err
                .println("   -D mapreduce.output.fileoutputformat.compress=true");
        System.err
                .println("   -D mapreduce.output.fileoutputformat.compress.codec=org.apache.hadoop.io.compress.GzipCodec");
        System.err
                .println("   -D mapreduce.output.fileoutputformat.compress.type=BLOCK");
        System.err
                .println("  Additionally, the following SCAN properties can be specified");
        System.err.println("  to control/limit what is exported..");
        System.err.println("   -D " + TableInputFormat.SCAN_COLUMN_FAMILY
                + "=<familyName>");
        System.err.println("   -D " + RAW_SCAN + "=true");
        System.err.println("   -D " + TableInputFormat.SCAN_ROW_START
                + "=<CompanyID(Short),DeviceID(Short),yyyy-MM-dd(String)>");
        System.err.println("   -D " + TableInputFormat.SCAN_ROW_STOP
                + "=<CompanyID(Short),DeviceID(Short),yyyy-MM-dd(String)>");
        System.err
                .println("For performance consider the following properties:\n"
                        + "   -Dhbase.client.scanner.caching=100\n"
                        + "   -Dmapreduce.map.speculative=false\n"
                        + "   -Dmapreduce.reduce.speculative=false");
        System.err
                .println("For tables with very wide rows consider setting the batch size as below:\n"
                        + "   -D" + EXPORT_BATCHING + "=10");
    }

    /**
     * Main entry point.
     *
     * @param args
     *            The command line parameters.
     * @throws Exception
     *             When running the job fails.
     */
    public static void main(String[] args) throws Exception {
        System.setProperty("HADOOP_USER_NAME", "hdfs");
        UnixSystem us = new UnixSystem();
        System.out.println("Unix Username : " + us.getUsername());
        // -----------------------------------------------------
        Configuration conf = HBaseConfiguration.create();
        String[] otherArgs = new GenericOptionsParser(conf, args)
                .getRemainingArgs();
        if (otherArgs.length < 2) {
            usage("Wrong number of arguments: " + otherArgs.length);
            System.exit(-1);
        }
        // Check StartRow And StopRow
        String rowStart = conf.get(TableInputFormat.SCAN_ROW_START);
        String rowStop = conf.get(TableInputFormat.SCAN_ROW_STOP);
        if(rowStart == null && rowStop == null) {
            // do nothing
        } else {
            if(rowStart != null && rowStop != null) {
                // check rowStart
                String strToCheck[] = rowStart.split(",");
                try {
                    Short.valueOf(strToCheck[0]);
                    Short.valueOf(strToCheck[1]);
                } catch (Exception e) {
                    usage("String parsed to Short error ! Wrong argument of " + TableInputFormat.SCAN_ROW_START + " : " + rowStart);
                    System.exit(-1);
                }
                try {
                    format.parse(strToCheck[2]);
                } catch (Exception e) {
                    usage("yyyy-MM-dd String parsed to Date error ! Wrong argument of " + TableInputFormat.SCAN_ROW_START + " : " + rowStart);
                    System.exit(-1);
                }
                // check rowStop
                strToCheck = rowStop.split(",");
                try {
                    Short.valueOf(strToCheck[0]);
                    Short.valueOf(strToCheck[1]);
                } catch (Exception e) {
                    usage("String parsed to Short error ! Wrong argument of " + TableInputFormat.SCAN_ROW_STOP + " : " + rowStop);
                    System.exit(-1);
                }
                try {
                    format.parse(strToCheck[2]);
                } catch (Exception e) {
                    usage("yyyy-MM-dd String parsed to Date error ! Wrong argument of " + TableInputFormat.SCAN_ROW_STOP + " : " + rowStop);
                    System.exit(-1);
                }
            } else {
                usage(TableInputFormat.SCAN_ROW_START + " and " + TableInputFormat.SCAN_ROW_STOP + " must both not be null.");
                System.exit(-1);
            }
        }
        Job job = createSubmittableJob(conf, otherArgs);
        System.exit(job.waitForCompletion(true) ? 0 : 1);
    }
}

```
