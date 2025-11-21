use reqwest::{header::{HeaderMap, HeaderValue, AUTHORIZATION}, Client, Url};
use serde::{de::DeserializeOwned, Serialize};

use crate::suite::config::Config;

#[derive(Clone)]
pub struct EdgehogClient {
    url: Url,
    client: Client,
}

impl EdgehogClient {
    pub fn create(config: &Config) -> eyre::Result<Self> {
        let full_url = format!(
            "{}://{}/tenants/{}/api",
            config.scheme, config.hostname, config.tenant
        ).parse()?;

        let mut headers = HeaderMap::new();
        let mut token = HeaderValue::try_from(format!("Bearer {}", config.bearer))?;
        token.set_sensitive(true);

        headers.insert(AUTHORIZATION, token);   

        let client = reqwest::Client::builder().default_headers(headers).build()?;

        Ok(Self{
            url: full_url,
            client
        })
    }

    pub async fn send<T, U>(&self, value: &T) -> eyre::Result<graphql_client::Response<U>> where T: Serialize, U: DeserializeOwned {
        self.client.post(self.url.clone()).json(value).send().await?.error_for_status()?.json().await.map_err(Into::into)
    }
}
