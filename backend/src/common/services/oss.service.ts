import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import OSS from 'ali-oss';

@Injectable()
export class OssService {
  private client: OSS;

  constructor(private readonly config: ConfigService) {
    const ossEndpoint = this.config.get('aliyun.ossEndpoint', '');
    this.client = new OSS({
      region: ossEndpoint.replace('oss-cn-', '').replace('.aliyuncs.com', ''),
      accessKeyId: this.config.get('aliyun.accessKeyId', ''),
      accessKeySecret: this.config.get('aliyun.accessKeySecret', ''),
      bucket: this.config.get('aliyun.ossBucket', ''),
      endpoint: ossEndpoint,
      secure: true,
    });
  }

  /** 上传文件到 OSS，支持 Buffer 或文件路径 */
  async put(path: string, content: Buffer | string): Promise<string> {
    await this.client.put(path, content);
    return `https://${this.config.get('aliyun.ossBucket', '')}.${this.config.get('aliyun.ossEndpoint', '').replace('http://', '')}/${path}`;
  }

  /** 删除 OSS 文件 */
  async delete(path: string): Promise<void> {
    try {
      await this.client.delete(path);
    } catch {}
  }
}
