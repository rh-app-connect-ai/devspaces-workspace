"""Reset lab data: database invoices table and S3 bucket."""
import argparse
import urllib.request
import tempfile
import os
import ssl
import warnings

# Suppress SSL warnings for self-signed certs
warnings.filterwarnings("ignore", message=".*Unverified HTTPS.*")

BLUE = "\033[0;34m"
GREEN = "\033[0;32m"
RED = "\033[0;31m"
YELLOW = "\033[0;33m"
RESET = "\033[0m"

def info(msg):
    print(f"{BLUE}INFO:{RESET} {msg}")

def success(msg):
    print(f"{GREEN}DONE:{RESET} {msg}")

def error(msg):
    print(f"{RED}ERROR:{RESET} {msg}")

def warn(msg):
    print(f"{YELLOW}WARN:{RESET} {msg}")

DEFAULT_INVOICE_XML = r'''<Invoice>
   <InvoiceNumber>61356291</InvoiceNumber>
   <DateOfIssue>20120906</DateOfIssue>
   <Seller>
      <Name>Rodriguez-Stevens</Name>
      <Address>
         <Street>2280 Angela Plain</Street>
         <City>Hortonshire</City>
         <State>MS</State>
         <PostalCode>93248</PostalCode>
      </Address>
      <TaxId>939988477</TaxId>
      <IBAN>GB50ACIE59715038217063</IBAN>
   </Seller>
   <Client>
      <Name>Chapman, Kim and Green</Name>
      <Address>
         <Street>64731 James Branch</Street>
         <City>Smithmouth</City>
         <State>NC</State>
         <PostalCode>26872</PostalCode>
      </Address>
      <TaxId>949849105</TaxId>
   </Client>
   <Items>
      <Item>
         <Number>1</Number>
         <ProductID>WINEGLASS01</ProductID>
         <Description>Wine Glasses Goblets Pair Clear Glass</Description>
         <Quantity>5</Quantity>
         <UnitOfMeasure>Each</UnitOfMeasure>
         <NetPrice>12</NetPrice>
         <NetWorth>60</NetWorth>
         <VATPercentage>10</VATPercentage>
         <GrossWorth>66</GrossWorth>
      </Item>
      <Item>
         <Number>2</Number>
         <ProductID>WINERACK01</ProductID>
         <Description>With Hooks Stemware Storage Multiple Uses Iron Wine Rack Hanging Glass</Description>
         <Quantity>4</Quantity>
         <UnitOfMeasure>Each</UnitOfMeasure>
         <NetPrice>28.08</NetPrice>
         <NetWorth>112.32</NetWorth>
         <VATPercentage>10</VATPercentage>
         <GrossWorth>123.55</GrossWorth>
      </Item>
      <Item>
         <Number>3</Number>
         <ProductID>CORKSCREW01</ProductID>
         <Description>Replacement Corkscrew Parts Spiral Worm Wine Opener Bottle Houdini</Description>
         <Quantity>1</Quantity>
         <UnitOfMeasure>Each</UnitOfMeasure>
         <NetPrice>7.5</NetPrice>
         <NetWorth>7.5</NetWorth>
         <VATPercentage>10</VATPercentage>
         <GrossWorth>8.25</GrossWorth>
      </Item>
      <Item>
         <Number>4</Number>
         <ProductID>STEMLESS01</ProductID>
         <Description>HOME ESSENTIALS GRADIENT STEMLESS WINE GLASSES SET OF 4 20 FL OZ (591 ml) NEW</Description>
         <Quantity>1</Quantity>
         <UnitOfMeasure>Each</UnitOfMeasure>
         <NetPrice>12.99</NetPrice>
         <NetWorth>12.99</NetWorth>
         <VATPercentage>10</VATPercentage>
         <GrossWorth>14.29</GrossWorth>
      </Item>
   </Items>
   <Summary>
      <VATPercentage>10</VATPercentage>
      <NetWorth>192.81</NetWorth>
      <VATAmount>19.28</VATAmount>
      <GrossWorth>212.09</GrossWorth>
   </Summary>
</Invoice>'''

INVOICE_PDF_URL = "https://raw.githubusercontent.com/rh-app-connect-ai/lab-deploy-assets/main/invoices/invoice_61356291.pdf"
INVOICE_PDF_NAME = "invoice_61356291.pdf"


def reset_database(db_user, db_pass):
    import psycopg2

    info(f"Connecting to database as {db_user}...")
    try:
        conn = psycopg2.connect(
            host="postgres",
            port=5432,
            dbname="labdb",
            user=db_user,
            password=db_pass,
            options=f"-c search_path={db_user}",
            connect_timeout=5
        )
    except psycopg2.OperationalError:
        error("Cannot connect to the database.")
        warn("The 'postgres' service is not reachable.")
        warn("Please establish the Service Interconnect network first.")
        warn("Run: si-setup")
        raise SystemExit(1)

    conn.autocommit = True
    cur = conn.cursor()

    info("Truncating invoices table...")
    cur.execute("TRUNCATE TABLE invoices")

    info("Inserting default invoice record...")
    cur.execute("INSERT INTO invoices (id, data) VALUES (%s, %s)",
                ("61356291", DEFAULT_INVOICE_XML))

    cur.close()
    conn.close()
    success("Database reset complete.")


def reset_s3(s3_access, s3_secret, s3_endpoint, bucket):
    import boto3
    from botocore.config import Config

    info(f"Connecting to S3 bucket '{bucket}'...")
    s3 = boto3.client(
        "s3",
        endpoint_url=s3_endpoint,
        aws_access_key_id=s3_access,
        aws_secret_access_key=s3_secret,
        verify=False,
        config=Config(signature_version="s3v4")
    )

    # Create bucket if it doesn't exist
    try:
        s3.head_bucket(Bucket=bucket)
    except s3.exceptions.ClientError:
        info(f"Bucket '{bucket}' not found, creating it...")
        s3.create_bucket(Bucket=bucket)

    # Delete all objects
    response = s3.list_objects_v2(Bucket=bucket)
    if "Contents" in response:
        objects = [{"Key": obj["Key"]} for obj in response["Contents"]]
        s3.delete_objects(Bucket=bucket, Delete={"Objects": objects})
        info(f"Deleted {len(objects)} object(s).")
    else:
        info("Bucket already empty.")

    # Download and upload default invoice PDF
    info("Downloading default invoice PDF...")
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
        req = urllib.request.urlopen(INVOICE_PDF_URL, context=ctx)
        tmp.write(req.read())
        tmp_path = tmp.name

    info(f"Uploading {INVOICE_PDF_NAME} to bucket '{bucket}'...")
    s3.upload_file(tmp_path, bucket, INVOICE_PDF_NAME)
    os.unlink(tmp_path)
    success("S3 reset complete.")


def main():
    parser = argparse.ArgumentParser(description="Reset lab data")
    parser.add_argument("--db-user", required=True)
    parser.add_argument("--db-pass", required=True)
    parser.add_argument("--s3-access", required=True)
    parser.add_argument("--s3-secret", required=True)
    parser.add_argument("--s3-endpoint", required=True)
    parser.add_argument("--bucket", required=True)
    args = parser.parse_args()

    reset_database(args.db_user, args.db_pass)
    reset_s3(args.s3_access, args.s3_secret, args.s3_endpoint, args.bucket)
    print(f"\n{GREEN}All lab data reset to defaults.{RESET}")


if __name__ == "__main__":
    main()
