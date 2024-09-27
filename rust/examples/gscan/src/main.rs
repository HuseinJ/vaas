use clap::{command, ArgAction, Parser};
use reqwest::Url;
use std::{collections::HashMap, path::PathBuf};
use vaas::{
    auth::authenticators::ClientCredentials, error::VResult, CancellationToken, Connection, Vaas,
    VaasVerdict,
};

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    #[arg(
        short = 'i',
        long = "client_id",
        env = "CLIENT_ID",
        help = "Set your VaaS client ID"
    )]
    client_id: String,

    #[arg(
        short = 's',
        long = "client_secret",
        env = "CLIENT_SECRET",
        help("Set your VaaS client secret")
    )]
    client_secret: String,

    #[arg(long, help = "Lookup the SHA256 hash")]
    use_hash_lookup: bool,

    #[arg(long, help = "Use the cache")]
    use_cache: bool,

    #[arg(short='f', long, action=ArgAction::Append, required_unless_present("urls"), help="List of files to scan separated by whitepace")]
    files: Vec<PathBuf>,

    #[arg(short='u', long, action=ArgAction::Append, required_unless_present("files"), help="List of urls to scan separated by whitepace")]
    urls: Vec<Url>,
}

#[tokio::main]
async fn main() -> VResult<()> {
    let args = Args::parse();

    // TODO: dotenv support
    // TODO: directory support

    let authenticator = ClientCredentials::new(args.client_id.clone(), args.client_secret.clone());
    let vaas_connection = Vaas::builder(authenticator)
        .use_hash_lookup(args.use_hash_lookup)
        .use_cache(args.use_cache)
        .build()?
        .connect()
        .await?;

    let file_verdicts = scan_files(args.files.as_ref(), &vaas_connection).await?;
    let url_verdicts = scan_urls(args.urls.as_ref(), &vaas_connection).await?;

    file_verdicts
        .iter()
        .for_each(|(f, v)| print_verdicts(f.display().to_string(), v));

    url_verdicts.iter().for_each(|(u, v)| print_verdicts(u, v));

    Ok(())
}

fn print_verdicts<I: AsRef<str>>(i: I, v: &VResult<VaasVerdict>) {
    print!("{} -> ", i.as_ref());
    match v {
        Ok(v) => {
            println!("{}", v.verdict);
        }
        Err(e) => {
            println!("{}", e.to_string());
        }
    };
}

async fn scan_files<'a>(
    files: &'a [PathBuf],
    vaas_connection: &Connection,
) -> VResult<Vec<(&'a PathBuf, VResult<VaasVerdict>)>> {
    let ct = CancellationToken::from_minutes(1);
    let verdicts = vaas_connection.for_file_list(files, &ct).await;
    let results = files.iter().zip(verdicts).collect();

    Ok(results)
}

async fn scan_urls(
    urls: &[Url],
    vaas_connection: &Connection,
) -> VResult<HashMap<Url, Result<VaasVerdict, vaas::error::Error>>> {
    let ct = CancellationToken::from_minutes(1);
    let mut verdicts = HashMap::new();
    for url in urls {
        let verdict = vaas_connection.for_url(url, &ct).await;
        verdicts.insert(url.to_owned(), verdict);
    }

    Ok(verdicts)
}
