import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity';

@Injectable()
export class UserService {
  constructor(@InjectRepository(User) private repo: Repository<User>) {}

  findById(id: string) {
    return this.repo.findOne({ where: { id } }).then((user) => {
      if (!user) return null;
      // 只暴露必要字段，不返回 hashedPassword
      return {
        id: user.id,
        phone: user.phone,
        name: user.name,
        avatar: user.avatar,
        createdAt: user.createdAt,
        hasPassword: !!user.hashedPassword,
      };
    });
  }

  findByPhone(phone: string) {
    return this.repo.findOne({ where: { phone } });
  }

  async update(id: string, data: Partial<User>) {
    const user = await this.repo.findOne({ where: { id } });
    if (!user) throw new NotFoundException('用户不存在');
    Object.assign(user, data);
    await this.repo.save(user);
    return this.findById(id);
  }
}
