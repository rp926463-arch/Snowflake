--**Using Storage Integration
--how to get storage_aws_role_arn : https://docs.snowflake.com/en/user-guide/data-load-s3-config-storage-integration#step-2-create-the-iam-role-in-aws
----create IAM role with trusted entity type as AWS account
----This account
----add policy AmazonS3FullAccess
----create role
------This completes authentication steps from aws side, use principal created by above role in below create integration statement(storage_aws_role_arn)

create or replace storage integration aws_s3_integration
    type = external_stage
    storage_provider = s3
    storage_aws_role_arn = 'arn:aws:iam::761018849000:role/SnowflakeS3role'
    enabled = true
    storage_allowed_locations = ( 's3://test-s3-bucket9/external_tables/ext_seattle/');
    -- storage_blocked_locations = ( 's3://<location1>', 's3://<location2>' )
    -- comment = '<comment>';

describe integration aws_s3_integration;

--copy STORAGE_AWS_IAM_USER_ARN and update aws role trust relationship principal

create or replace STAGE DBT_TEST.SEEDS.AWS_S3_STAGE
    URL = 's3://test-s3-bucket9/external_tables/ext_seattle/'
    STORAGE_INTEGRATION = AWS_S3_INTEGRATION
    DIRECTORY = ( ENABLE = true );

list @DBT_TEST.SEEDS.AWS_S3_STAGE;


--**Using AWS keys
----create new use in IAM(snowflake_user) with policy AmazonS3FullAccess & get aws_key_id, aws_secret_key
create or replace STAGE DBT_TEST.SEEDS.AWS_S3_STAGE_tmp
    URL = 's3://test-s3-bucket9/external_tables/ext_seattle/'
    CREDENTIALS = (aws_key_id = '', aws_secret_key = '')
    DIRECTORY = ( ENABLE = true );

list @DBT_TEST.SEEDS.AWS_S3_STAGE_tmp;

--________________________________________
create database external_tables;

create schema s3_tables;

create or replace external table ext_seattle_without_schema
    with location = @DBT_TEST.SEEDS.AWS_S3_STAGE
    file_format = (type = parquet);

select * from ext_seattle_without_schema;

--________________________________________
create or replace file format parquet_format
    type = parquet;

create or replace external table ext_seattle_with_schema_detection
    using template (
        select array_agg(object_construct(*))
        from table(
            infer_schema(
                location=>'@DBT_TEST.SEEDS.AWS_S3_STAGE',
                file_format=>'parquet_format'
            )
        )
    )
    location = @DBT_TEST.SEEDS.AWS_S3_STAGE
    file_format = parquet_format
    auto_refresh=false;

select get_ddl('table', 'ext_seattle_with_schema_detection');

select * from ext_seattle_with_schema_detection;


--________________________________________
select t.$1, t.$2 from @DBT_TEST.SEEDS.AWS_S3_STAGE (file_format => 'parquet_format') t;

create or replace external table ext_seattle_with_schema(
    datatype varchar as (value:DATATYPE::varchar),
    DATASUBTYPE varchar as (value:DATASUBTYPE::varchar),
    datetime timestamp_ntz as (value:DATETIME::timestamp),
    category varchar as (value:CATEGORY::varchar),
    subcategory number(38,0) as (value:SUBCATEGORY::number),
    status  number(38,0) as (value:STATUS::number),
    address varchar as (value:ADDRESS::varchar),
    lattitude double as (value:LATTITUDE::double),
    longitude double as (value:LONGITUDE::double)
) with location = @DBT_TEST.SEEDS.AWS_S3_STAGE
--auto_refresh = true
file_format = (format_name = parquet_format);


select * exclude value from ext_seattle_with_schema;

