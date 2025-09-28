import { NextResponse } from "next/server";
import { minikitConfig } from "../../../minikit.config";

export async function GET() {
  return NextResponse.json({
    frame: {
      name: minikitConfig.miniapp.name,
      version: minikitConfig.miniapp.version,
      iconUrl: minikitConfig.miniapp.iconUrl,
      homeUrl: minikitConfig.miniapp.homeUrl,
      imageUrl: minikitConfig.miniapp.heroImageUrl,
      splashImageUrl: minikitConfig.miniapp.splashImageUrl,
      splashBackgroundColor: minikitConfig.miniapp.splashBackgroundColor,
      webhookUrl: minikitConfig.miniapp.webhookUrl,
      subtitle: minikitConfig.miniapp.subtitle,
      description: minikitConfig.miniapp.description,
      primaryCategory: minikitConfig.miniapp.primaryCategory,
    },
    accountAssociation: minikitConfig.accountAssociation,
    baseBuilder: minikitConfig.baseBuilder,
  });
}