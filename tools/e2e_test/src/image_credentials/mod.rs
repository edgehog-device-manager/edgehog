use mutations::create_image_credentials::CreateImageCredentials;
use queries::get_image_credentials::GetImageCredentials;

use crate::suite::client;

pub mod mutations;
pub mod queries;

pub async fn run_test(client: client::EdgehogClient) -> eyre::Result<()> {
    let image_credentials_result = CreateImageCredentials::create_image_credentials(
        &client,
        "user2".to_string(),
        "password".to_string(),
        "label2".to_string(),
    )
    .await?;

    dbg!(image_credentials_result);

    let id = String::from("1");

    match GetImageCredentials::get_image_credentials(&client, id).await {
        Ok(response_data) => {
            dbg!(response_data);
            ()
        }
        Err(error) => {
            let _ = dbg!(error);
            ()
        }
    };

    Ok(())
}
