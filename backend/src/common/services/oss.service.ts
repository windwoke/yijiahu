import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import OSS from 'ali-oss';

@Injectable()
export class OssService {
  private client: OSS;

  constructor(private readonly config: ConfigService) {
    this.client = new OSS({
      region: this.config.get('aliyun.ossEndpoint', '').replace('oss-cn-', '').replace('.aliyuncs.com', ''),
      accessKeyId: this.config.get('aliyun.accessKeyId', ''),
      accessKeySecret: this.config.get('aliyun.accessKeySecret', ''),
      bucket: this.config.get('aliyun.ossBucket', ''),
      endpoint: this.config.get('aliyun.ossEndpoint', ''),
    });
  }

  /** 上传 Buffer 到 OSS，返回公网 URL */
  async put(path: string, buffer: Buffer, options?: OSS.PutStreamOptions): Promise<string> {
    await this.client.put(path, buffer, options);
    return `https://${this.config.get('aliyun.ossBucket', '')}.${this.config.get('aliyun.ossEndpoint', '').replace('http://', '')}/${path}`;
  }

  /** 删除 OSS 文件 */
  async delete(path: string): Promise<void> {
    try {
      await this.client.delete(path);
    } catch (_) {}
  }
}
