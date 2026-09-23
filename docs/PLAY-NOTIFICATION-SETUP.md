# Dev Google Play notification setup

This is the concrete configuration for SECUR4ALL-244/125, not evidence that
Google resources exist or that purchase processing is active. Use an authorized
operator in project `trustcheck-radar` (1034373992662). The runtime Play credential
must not receive project-administration permissions. No Google function is needed.

1. Enable Pub/Sub in the intended organization account/project. The last read-only
   check returned SERVICE_DISABLED; recheck after the owner confirms enablement.
2. Create dedicated push identity
   `tcr-dev-play-push@trustcheck-radar.iam.gserviceaccount.com`, without a downloaded
   private key or Play Console purchasing permission. Record its numeric unique ID
   for the Lambda subject check. The identity is only for signed push delivery.
3. Create topic `projects/trustcheck-radar/topics/trustcheckradar-dev-play-lifecycle`.
   Leave topic message retention unset and do not create extra subscriptions,
   snapshots or sinks. Grant `roles/pubsub.publisher` on this topic to
   `google-play-developer-notifications@system.gserviceaccount.com`.
4. Grant Pub/Sub service agent
   `service-1034373992662@gcp-sa-pubsub.iam.gserviceaccount.com`
   `roles/iam.serviceAccountTokenCreator` on the dedicated push identity only.
   The configuration operator also needs `iam.serviceAccounts.actAs` on that
   identity. Inspect existing bindings first; do not overwrite unrelated policy.
5. After deploying the reviewed callback and qualifying cleanup, create push
   subscription `projects/trustcheck-radar/subscriptions/trustcheckradar-dev-play-lifecycle`.
   Use the actual `notification_endpoint` Terraform output as its HTTPS endpoint.
   Configure authenticated delivery with the dedicated push identity and audience
   `https://api-dev.andmorethings.net/v1/notifications/google-play`.
   This audience is a stable token claim; it is not the callback URL.
6. Set subscription message retention to `600s`, retain acknowledged messages false,
   no dead-letter policy and no payload unwrapping. Do not add an AWS queue or DLQ.
   Read back these properties, topic retention and all subscriptions/snapshots before
   enabling delivery. Pending Google messages cannot be selectively erased at
   account deletion; handlers reject deleted accounts. Ten minutes is configured
   transport retention, not a physical-erasure guarantee.
7. In Play Console for `com.andmorethings.trustcheckradar`, configure the full topic
   name under Monetization setup / Real-time developer notifications. Select
   subscription and voided-purchase notifications. A Play test notification can
   qualify authenticated delivery without a mobile device, but does not prove a
   purchase, renewal, allowance reset, refund or acknowledgment transaction.

Before enabling writers, record exact artifact versions, live alias targets, IAM
qualification, inventory/backup checks, token expiry/deletion/export acceptance
and approval of any new checkpoint retention. A notification requests fresh Google
verification; its claimed event type alone never changes entitlement.

Do not log/paste notification bodies, purchase tokens, credentials or JWTs. Record
only configuration metadata, aggregate status and sanitized test outcomes. If
Google setup remains unavailable, keep its acceptance open while delivering the
independent AWS/Lambda component work. Physical cases belong in ATCR-148.

Sources checked 2026-09-23 UTC:
- [Google Play RTDN setup](https://developer.android.com/google/play/billing/getting-ready)
- [Authenticated Pub/Sub push](https://docs.cloud.google.com/pubsub/docs/authenticate-push-subscriptions)
- [Subscription retention properties](https://docs.cloud.google.com/pubsub/docs/subscription-properties)
