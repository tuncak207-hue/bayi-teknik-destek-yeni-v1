import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const adminEmail = process.env.SEED_ADMIN_EMAIL || 'admin@example.com';
  const adminPassword = process.env.SEED_ADMIN_PASSWORD || 'ChangeMe123!';

  const existingAdmin = await prisma.user.findUnique({ where: { email: adminEmail } });
  if (!existingAdmin) {
    const passwordHash = await bcrypt.hash(adminPassword, 12);
    await prisma.user.create({
      data: {
        firstName: 'Admin',
        lastName: 'Kullanıcı',
        company: 'Merkez',
        phone: '0000000000',
        email: adminEmail,
        passwordHash,
        role: 'ADMIN',
        status: 'ACTIVE',
      },
    });
    console.log(`Admin oluşturuldu: ${adminEmail} / ${adminPassword}`);
  } else {
    console.log('Admin zaten mevcut, atlanıyor.');
  }

  const groupNames = ['Yangın Alarm', 'Kamera', 'Honeywell', 'Hanwha', 'Teknik Destek'];
  for (const name of groupNames) {
    const existing = await prisma.group.findFirst({ where: { name } });
    if (!existing) {
      const group = await prisma.group.create({ data: { name } });
      await prisma.conversation.create({
        data: { type: 'GROUP', title: name, groupId: group.id },
      });
      console.log(`Grup oluşturuldu: ${name}`);
    }
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
